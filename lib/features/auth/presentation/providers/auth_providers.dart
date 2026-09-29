import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/storage/secure_session_storage.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/datasources/fake_auth_remote_datasource.dart';
import '../../data/datasources/supabase_auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';

final secureSessionStorageProvider = Provider<SecureSessionStorage>((ref) {
  return SecureSessionStorage();
});

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  // Keep alive so pending registration OTP state is not dropped mid-flow.
  ref.keepAlive();

  if (AppConfig.useFakeAuth || !AppConfig.hasSupabaseConfig) {
    return FakeAuthRemoteDataSource();
  }

  return SupabaseAuthRemoteDataSource();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remote: ref.watch(authRemoteDataSourceProvider),
    sessionStorage: ref.watch(secureSessionStorageProvider),
  );
});
