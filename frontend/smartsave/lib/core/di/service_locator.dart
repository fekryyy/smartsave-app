import 'package:get_it/get_it.dart';
import '../../services/google_auth_service.dart';
import '../../services/sync_service.dart';
import '../../services/sync/sync_engine.dart';
import '../../services/sync/sync_queue_manager.dart';
import '../../services/sync/conflict_resolver.dart';

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

  // ── Sync Services (singletons) ──
  // ConflictResolver, SyncQueueManager, SyncEngine, and SyncService are
  // all singletons by design (factory constructors return the same instance).
  // Registering them in GetIt allows providers to depend on them via DI
  // rather than accessing static instances directly.
  getIt.registerLazySingleton<ConflictResolver>(() => ConflictResolver());
  getIt.registerLazySingleton<SyncQueueManager>(() => SyncQueueManager());
  getIt.registerLazySingleton<SyncEngine>(() => SyncEngine());
  getIt.registerLazySingleton<SyncService>(() => SyncService());
}
