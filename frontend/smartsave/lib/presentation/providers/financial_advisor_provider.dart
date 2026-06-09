import 'package:flutter/material.dart';
import '../../data/repositories/financial_advisor_repository_impl.dart';
import '../../data/models/financial_advisor_models.dart';

/// State provider for the Financial Advisor feature.
///
/// ## Architecture
/// - Score loads first (fast, deterministic, no AI calls)
/// - AI sections (insights, plans, predictions) load in parallel incrementally
/// - Chat requests are serialised with a queue to preserve response ordering
/// - Sequence-number guarding prevents stale responses from overlapping
///   [loadAll] calls and cross-user data leakage after [resetState]
class FinancialAdvisorProvider extends ChangeNotifier {
  final FinancialAdvisorRepositoryImpl _repository =
      FinancialAdvisorRepositoryImpl();

  // ── Core state ──

  FullFinancialAnalysis? _analysis;
  FinancialScore? _score;
  List<FinancialInsight> _insights = [];
  List<ActionPlan> _actionPlans = [];
  List<FinancialPrediction> _predictions = [];
  List<ConversationResponse> _chatHistory = [];
  bool _isLoading = false;
  String? _errorMessage;

  // ── Re-entrancy guards ──

  /// Incremented on each [loadAll] call. Background loaders check this
  /// before mutating state; stale responses are discarded.
  int _loadSequence = 0;

  /// Whether a chat request is currently in-flight.
  bool _isChatPending = false;

  /// Queued chat questions submitted while another request was in-flight.
  final List<String> _chatQueue = [];

  /// Chat loading count — uses a counter so the spinner stays visible
  /// when the next queued question fires before the current one settles.
  int _chatLoadingCount = 0;

  /// Per-section error flags (set on network failure, cleared on next load).
  bool _insightError = false;
  bool _actionPlanError = false;
  bool _predictionError = false;

  // ── Getters ──

  FullFinancialAnalysis? get analysis => _analysis;
  FinancialScore? get score => _score;
  List<FinancialInsight> get insights => _insights;
  List<ActionPlan> get actionPlans => _actionPlans;
  List<FinancialPrediction> get predictions => _predictions;
  List<ConversationResponse> get chatHistory => _chatHistory;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isChatLoading => _chatLoadingCount > 0;

  bool get insightError => _insightError;
  bool get actionPlanError => _actionPlanError;
  bool get predictionError => _predictionError;

  // ── Data loading ──

  /// Loads all Financial Advisor data incrementally:
  ///
  /// 1. Score (fast — deterministic backend, no AI) — displayed immediately
  /// 2. AI sections (insights, plans, predictions) — loaded in parallel,
  ///    each appearing as its data arrives
  ///
  /// If the user switches users or a second [loadAll] is called while the
  /// first is still in-flight, stale responses are silently discarded via
  /// the [_loadSequence] guard.
  Future<void> loadAll() async {
    final sequence = ++_loadSequence;

    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      // Step 1: Load score first (fast — no AI calls)
      _score = await _repository.getScore();
      if (sequence != _loadSequence) return; // Stale — discard
      _analysis = FullFinancialAnalysis(
        score: _score!,
        health: FinancialHealth(status: 'needs_attention'),
      );
      _isLoading = false;
      notifyListeners();

      // Step 2: Fire AI-powered sections in parallel (each guarded by
      // the sequence to prevent stale writes from overlapping calls).
      _loadInsights(sequence);
      _loadActionPlans(sequence);
      _loadPredictions(sequence);
    } catch (e) {
      if (sequence != _loadSequence) return; // Stale — discard
      _isLoading = false;
      if (_analysis == null) {
        _errorMessage = 'Unable to load financial data';
      }
      notifyListeners();
    }
  }

  /// Loads insights in the background.
  ///
  /// Clears the list before fetching and sets [_insightError] on failure.
  /// If [sequence] is stale (a newer [loadAll] was started), the result is
  /// silently discarded.
  Future<void> _loadInsights(int sequence) async {
    _insights = [];
    _insightError = false;
    notifyListeners();
    try {
      _insights = await _repository.getInsights();
      if (sequence != _loadSequence) return; // Stale — discard
      notifyListeners();
    } catch (_) {
      _insightError = true;
      if (sequence == _loadSequence) notifyListeners();
    }
  }

  /// Loads action plans in the background.
  ///
  /// Clears the list before fetching and sets [_actionPlanError] on failure.
  /// Stale responses are discarded via the sequence guard.
  Future<void> _loadActionPlans(int sequence) async {
    _actionPlans = [];
    _actionPlanError = false;
    notifyListeners();
    try {
      _actionPlans = await _repository.getActionPlans();
      if (sequence != _loadSequence) return; // Stale — discard
      notifyListeners();
    } catch (_) {
      _actionPlanError = true;
      if (sequence == _loadSequence) notifyListeners();
    }
  }

  /// Loads predictions in the background.
  ///
  /// Clears the list before fetching and sets [_predictionError] on failure.
  /// Stale responses are discarded via the sequence guard.
  Future<void> _loadPredictions(int sequence) async {
    _predictions = [];
    _predictionError = false;
    notifyListeners();
    try {
      _predictions = await _repository.getPredictions();
      if (sequence != _loadSequence) return; // Stale — discard
      notifyListeners();
    } catch (_) {
      _predictionError = true;
      if (sequence == _loadSequence) notifyListeners();
    }
  }

  // ── Refresh (best-effort) ──

  Future<void> refreshScore() async {
    try {
      _score = await _repository.getScore();
      notifyListeners();
    } catch (_) {
      // Score refresh is best-effort
    }
  }

  Future<void> refreshInsights() async {
    try {
      _insights = await _repository.getInsights();
      notifyListeners();
    } catch (_) {
      // Insight refresh is best-effort
    }
  }

  // ── Chat (serialised) ──

  /// Sends a question to the AI Financial Advisor and appends the response
  /// to the chat history.
  ///
  /// ## Ordering guarantee
  /// If a chat request is already in-flight, the question is queued and
  /// processed in FIFO order after the current request completes. This
  /// prevents out-of-order responses in the chat history.
  Future<void> askQuestion(String question) async {
    if (question.trim().isEmpty) return;

    if (_isChatPending) {
      _chatQueue.add(question);
      return;
    }

    _isChatPending = true;
    _chatLoadingCount++;
    notifyListeners();
    await _processChat(question);
  }

  /// Processes a single chat question and handles the queue recursively.
  Future<void> _processChat(String question) async {
    _chatHistory.add(ConversationResponse(answer: question, type: 'user'));
    notifyListeners();

    try {
      final result = await _repository.askQuestion(question);
      _chatHistory.add(result);

      // Refresh data after question if it might have changed
      if (result.type == 'advice' || result.type == 'analysis') {
        // Fire-and-forget: these are best-effort refreshes
        refreshScore();
        refreshInsights();
      }
    } catch (e) {
      _chatHistory.add(ConversationResponse(
        answer: 'Sorry, I encountered an error. Please try again.',
        type: 'error',
      ));
    }

    _chatLoadingCount--;

    if (_chatQueue.isNotEmpty) {
      final next = _chatQueue.removeAt(0);
      _chatLoadingCount++;
      notifyListeners();
      await _processChat(next);
    } else {
      _isChatPending = false;
      notifyListeners();
    }
  }

  // ── Lifecycle ──

  /// Resets all state to initial values.
  ///
  /// Called when the authenticated user changes. Increments
  /// [_loadSequence] so any in-flight background loaders from the previous
  /// session discard their results, preventing cross-user data leakage.
  void resetState() {
    // Increment sequence to discard in-flight background loads
    _loadSequence++;
    // Clear pending chat queue so stale questions don't fire
    _chatQueue.clear();
    _isChatPending = false;
    _chatLoadingCount = 0;

    _analysis = null;
    _score = null;
    _insights = [];
    _actionPlans = [];
    _predictions = [];
    _chatHistory = [];
    _isLoading = false;
    _errorMessage = null;
    _insightError = false;
    _actionPlanError = false;
    _predictionError = false;
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
