import '../../repositories/analytics_repository.dart';

class GetDashboardUseCase {
  final AnalyticsRepository repository;
  GetDashboardUseCase(this.repository);

  Future<dynamic> call() {
    return repository.getDashboard();
  }
}
