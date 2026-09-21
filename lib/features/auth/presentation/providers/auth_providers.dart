import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hather_app/core/config/app_config.dart';
import 'package:hather_app/core/storage/secure_session_storage.dart';
import 'package:hather_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:hather_app/features/auth/data/datasources/fake_auth_remote_datasource.dart';
import 'package:hather_app/features/auth/data/datasources/supabase_auth_remote_datasource.dart';
import 'package:hather_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:hather_app/features/auth/domain/repositories/auth_repository.dart';

final secureSessionStorageProvider = Provider<SecureSessionStorage>((ref) {
  return SecureSessionStorage();
});

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  // Keep alive so pending registration OTP state is not dropped mid-flow.
  ref.keepAlive();

  if (AppConfig.useFakeAuth) {
    // Debug/profile only — AppConfig.useFakeAuth is always false in release.
    return FakeAuthRemoteDataSource();
  }

  if (!AppConfig.hasSupabaseConfig) {
    throw StateError(
      'Real auth requires SUPABASE_URL and '
      'SUPABASE_PUBLISHABLE_KEY (.env or --dart-define).',
    );
  }

  return SupabaseAuthRemoteDataSource();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remote: ref.watch(authRemoteDataSourceProvider),
    sessionStorage: ref.watch(secureSessionStorageProvider),
  );
});
