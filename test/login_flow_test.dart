import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/core/errors/failures.dart';
import 'package:hather_app/core/storage/secure_session_storage.dart';
import 'package:hather_app/features/auth/data/datasources/fake_auth_remote_datasource.dart';
import 'package:hather_app/features/auth/data/repositories/auth_repository_impl.dart';

void main() {
  late FakeAuthRemoteDataSource remote;
  late AuthRepositoryImpl repository;

  setUp(() {
    remote = FakeAuthRemoteDataSource(
      rateLimit: Duration.zero,
      networkDelay: Duration.zero,
    );
    repository = AuthRepositoryImpl(
      remote: remote,
      sessionStorage: InMemorySessionStorage(),
    );
  });

  test('unregistered phone returns PhoneNotRegisteredFailure', () async {
    final result = await repository.signInWithPhoneAndPassword(
      phone: '07756888722',
      secretCode: '123456',
    );

    expect(result.isFailure, isTrue);
    expect(result.failureOrNull<PhoneNotRegisteredFailure>(), isNotNull);
    expect(
      result.failureOrNull<PhoneNotRegisteredFailure>()!.phoneE164,
      '+9647756888722',
    );
  });

  test('registered phone with wrong password returns InvalidPasswordFailure',
      () async {
    await repository.registerAccount(
      fullName: 'سارة',
      phone: '07901234567',
      secretCode: '123456',
    );
    await repository.signOut();

    final result = await repository.signInWithPhoneAndPassword(
      phone: '07901234567',
      secretCode: 'wrong1',
    );

    expect(result.isFailure, isTrue);
    expect(result.failureOrNull<InvalidPasswordFailure>(), isNotNull);
  });

  test('registered phone with correct password succeeds', () async {
    await repository.registerAccount(
      fullName: 'سارة',
      phone: '07901234567',
      secretCode: '123456',
    );
    await repository.signOut();

    final result = await repository.signInWithPhoneAndPassword(
      phone: '07901234567',
      secretCode: '123456',
    );

    expect(result.isSuccess, isTrue);
  });

  test('resolve server failure does not redirect as unregistered', () async {
    remote.resolveLoginPhoneFailure = const NetworkFailure();

    final result = await repository.signInWithPhoneAndPassword(
      phone: '07756888722',
      secretCode: '123456',
    );

    expect(result.isFailure, isTrue);
    expect(result.failureOrNull<NetworkFailure>(), isNotNull);
    expect(result.failureOrNull<PhoneNotRegisteredFailure>(), isNull);
  });

  test('rate limited resolve stays on login flow failure', () async {
    remote.resolveLoginPhoneFailure = const TooManyRequestsFailure();

    final result = await repository.signInWithPhoneAndPassword(
      phone: '07756888722',
      secretCode: '123456',
    );

    expect(result.isFailure, isTrue);
    expect(result.failureOrNull<TooManyRequestsFailure>(), isNotNull);
  });

  test('captain account wrong password is not treated as unregistered', () async {
    await repository.registerAccount(
      fullName: 'كابتن',
      phone: '07801111111',
      secretCode: '123456',
    );
    await repository.signOut();

    final result = await repository.signInWithPhoneAndPassword(
      phone: '07801111111',
      secretCode: 'badpwd',
    );

    expect(result.failureOrNull<InvalidPasswordFailure>(), isNotNull);
  });

  test('phone with pending OTP is not treated as registered on login', () async {
    await repository.startRegistration(
      fullName: 'علي',
      phone: '07756888722',
      secretCode: '123456',
    );

    final result = await repository.signInWithPhoneAndPassword(
      phone: '07756888722',
      secretCode: '123456',
    );

    expect(result.isFailure, isTrue);
    expect(result.failureOrNull<PhoneNotRegisteredFailure>(), isNotNull);
  });
}
