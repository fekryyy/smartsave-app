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
  String? _error;

  // Getters
  FullFinancialAnalysis? get analysis => _analysis;
  FinancialScore? get score => _score;
  List<FinancialInsight> get insights => _insights;
  List<ActionPlan> get actionPlans => _actionPlans;
  List<FinancialPrediction> get predictions => _predictions;
  List<ConversationResponse> get chatHistory => _chatHistory;
  bool get isLoading => _isLoading;
  bool get isChatLoading => _isChatLoading;
  String? get error => _error;

  // Load all data in parallel
  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getFullAnalysis(),
        _repository.getInsights(),
        _repository.getActionPlans(),
        _repository.getPredictions(),
      ]);

      _analysis = results[0] as FullFinancialAnalysis;
      _score = _analysis!.score;
      _insights = results[1] as List<FinancialInsight>;
      _actionPlans = results[2] as List<ActionPlan>;
      _predictions = results[3] as List<FinancialPrediction>;
    } catch (e) {
      _error = e.toString();
      // Try loading individually
      await _loadIndividually();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadIndividually() async {
    try {
      _score = await _repository.getScore();
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
}
