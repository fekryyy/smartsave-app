import 'package:get_it/get_it.dart';
import '../../services/google_auth_service.dart';

/// Application-wide service locator using [GetIt].
///
/// Centralizes dependency injection for services that need to be shared
/// across providers and screens. Follows the Service Locator pattern
/// and integrates cleanly with the existing direct-instantiation codebase
/// without forcing a full DI migration.
///
/// Usage:
/// ```dart
/// await setupServiceLocator();
/// // Later, in any provider or screen:
/// final googleAuth = getIt<GoogleAuthService>();
/// ```
final GetIt getIt = GetIt.instance;

/// Registers all application-level dependencies.
///
/// Call once during app startup (in [main]) before [runApp].
/// All registrations are lazy singletons — initialized only on first access.
Future<void> setupServiceLocator() async {
  // ── Auth Services ──
  getIt.registerLazySingleton<GoogleAuthService>(() => GoogleAuthService());
}
