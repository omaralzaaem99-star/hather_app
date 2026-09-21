import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/core/errors/failures.dart';
import 'package:hather_app/core/storage/secure_session_storage.dart';
import 'package:hather_app/features/auth/data/datasources/fake_auth_remote_datasource.dart';
import 'package:hather_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:hather_app/features/auth/domain/entities/phone_registration_status.dart';

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

  Future<void> completeRegistration({
    required String fullName,
    required String phone,
    required String secretCode,
  }) async {
    final start = await repository.startRegistration(
      fullName: fullName,
      phone: phone,
      secretCode: secretCode,
    );
    expect(start.isSuccess, isTrue, reason: 'startRegistration');
    final challenge = start.valueOrNull!;
    final verify = await repository.verifyOtp(
      challengeId: challenge.challengeId,
      otp: challenge.debugOtp!,
      purpose: challenge.purpose,
      fullName: fullName,
      phone: challenge.phone,
      secretCode: secretCode,
    );
    expect(verify.isSuccess, isTrue, reason: 'verifyOtp');
  }

  group('TEST A — existing confirmed user', () {
    test('blocks before OTP and returns PhoneAlreadyExistsFailure', () async {
      await completeRegistration(
        fullName: 'كابتن حاضر',
        phone: '07828154686',
        secretCode: '123456',
      );

      final again = await repository.startRegistration(
        fullName: 'محاولة ثانية',
        phone: '07828154686',
        secretCode: '654321',
      );

      expect(again.isFailure, isTrue);
      expect(again.failureOrNull<PhoneAlreadyExistsFailure>(), isNotNull);
      expect(
        again.failureOrNull<PhoneAlreadyExistsFailure>()?.phoneE164,
        '+9647828154686',
      );
    });
  });

  group('TEST B — existing captain', () {
    test('blocks before OTP for captain account', () async {
      await completeRegistration(
        fullName: 'كابتن',
        phone: '07801112222',
        secretCode: '123456',
      );
      await repository.convertToCaptain();

      final again = await repository.startRegistration(
        fullName: 'كابتن جديد',
        phone: '07801112222',
        secretCode: '654321',
      );

      expect(again.isFailure, isTrue);
      expect(again.failureOrNull<PhoneAlreadyExistsFailure>(), isNotNull);
    });
  });

  group('TEST C — unverified registration', () {
    test('allows resend OTP and OTP screen flow', () async {
      final first = await repository.startRegistration(
        fullName: 'غير مكتمل',
        phone: '07803334444',
        secretCode: '123456',
      );
      expect(first.isSuccess, isTrue);
      expect(first.valueOrNull!.debugOtp, isNotNull);

      final retry = await repository.startRegistration(
        fullName: 'غير مكتمل ٢',
        phone: '07803334444',
        secretCode: '654321',
      );
      expect(retry.isSuccess, isTrue);
      expect(retry.valueOrNull!.debugOtp, isNotNull);

      final status = await remote.checkPhoneRegistrationStatus(
        '+9647803334444',
      );
      expect(status, PhoneRegistrationStatus.pendingVerification);
    });
  });

  group('TEST D — new phone', () {
    test('signUp OTP flow succeeds', () async {
      final start = await repository.startRegistration(
        fullName: 'جديد',
        phone: '07905556666',
        secretCode: '123456',
      );
      expect(start.isSuccess, isTrue);
      expect(start.valueOrNull!.debugOtp, isNotNull);

      final status = await remote.checkPhoneRegistrationStatus(
        '+9647905556666',
      );
      expect(status, PhoneRegistrationStatus.pendingVerification);
    });
  });

  group('TEST E — phone format normalization', () {
    test('local and E164 are treated as same number', () async {
      await completeRegistration(
        fullName: 'تنسيق',
        phone: '07827778888',
        secretCode: '123456',
      );

      final localFormat = await repository.startRegistration(
        fullName: 'محاولة محلية',
        phone: '07827778888',
        secretCode: '123456',
      );
      final e164Format = await repository.startRegistration(
        fullName: 'محاولة دولية',
        phone: '+9647827778888',
        secretCode: '123456',
      );

      expect(localFormat.isFailure, isTrue);
      expect(e164Format.isFailure, isTrue);
      expect(
        localFormat.failureOrNull<PhoneAlreadyExistsFailure>()?.phoneE164,
        '+9647827778888',
      );
      expect(
        e164Format.failureOrNull<PhoneAlreadyExistsFailure>()?.phoneE164,
        '+9647827778888',
      );
    });
  });
}
