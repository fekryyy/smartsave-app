import '../datasources/remote/financial_advisor_remote_datasource.dart';
import '../models/financial_advisor_models.dart';

class FinancialAdvisorRepositoryImpl {
  final FinancialAdvisorRemoteDataSource _remoteDataSource = FinancialAdvisorRemoteDataSource();

  // ── Consent management ──

  /// Returns the current AI consent status: `{ aiConsent: bool, aiConsentDate: DateTime? }`.
  Future<Map<String, dynamic>> getConsentStatus() async {
    final response = await _remoteDataSource.getConsentStatus();
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  /// Accept AI consent for the current user.
  Future<void> acceptConsent() async {
    await _remoteDataSource.acceptConsent();
  }

  /// Revoke AI consent for the current user.
  Future<void> revokeConsent() async {
    await _remoteDataSource.revokeConsent();
  }

  // ── AI-powered endpoints ──

  Future<FullFinancialAnalysis> getFullAnalysis() async {
    final response = await _remoteDataSource.getFullAnalysis();
    return FullFinancialAnalysis.fromJson(response['data'] ?? {});
  }

  Future<FinancialScore> getScore() async {
    final response = await _remoteDataSource.getScore();
    return FinancialScore.fromJson(response['data'] ?? {});
  }

  Future<List<FinancialInsight>> getInsights() async {
    final response = await _remoteDataSource.getInsights();
    final items = (response['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return items.map((j) => FinancialInsight.fromJson(j)).toList();
  }

  Future<List<ActionPlan>> getActionPlans() async {
    final response = await _remoteDataSource.getActionPlan();
    final items = (response['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return items.map((j) => ActionPlan.fromJson(j)).toList();
  }

  Future<List<FinancialPrediction>> getPredictions() async {
    final response = await _remoteDataSource.getPredictions();
    final items = (response['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return items.map((j) => FinancialPrediction.fromJson(j)).toList();
  }

  Future<ConversationResponse> askQuestion(String question) async {
    final response = await _remoteDataSource.askQuestion(question);
    return ConversationResponse.fromJson(response['data'] ?? {});
  }
}
