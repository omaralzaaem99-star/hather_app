import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/core/errors/failures.dart';
import 'package:hather_app/core/storage/secure_session_storage.dart';
import 'package:hather_app/features/auth/data/datasources/fake_auth_remote_datasource.dart';
import 'package:hather_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:hather_app/features/auth/domain/entities/verify_otp_result.dart';

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

  test('registerAccount creates profile without OTP', () async {
    final result = await repository.registerAccount(
      fullName: 'سارة محمد',
      phone: '07901234567',
      secretCode: '123456',
    );
    expect(result.isSuccess, isTrue);
    final session = result.valueOrNull!;
    final user = session.user;
    expect(user.fullName, 'سارة محمد');
    expect(user.phone, '+9647901234567');
    expect(user.accountType.name, 'user');
    expect(user.accountStatus.name, 'active');
    expect(user.phoneVerified, isFalse);

    // Session is persisted after successful registration.
    final restored = await repository.restoreSession();
    expect(restored.valueOrNull, isNotNull);
    expect(restored.valueOrNull!.user.phone, '+9647901234567');

    final login = await repository.signInWithPhoneAndPassword(
      phone: '07901234567',
      secretCode: '123456',
    );
    expect(login.isSuccess, isTrue);
  });

  test('registerAccount rejects duplicate phone', () async {
    await repository.registerAccount(
      fullName: 'نورة',
      phone: '07501234567',
      secretCode: '123456',
    );
    final again = await repository.registerAccount(
      fullName: 'نورة ٢',
      phone: '07501234567',
      secretCode: '123456',
    );
    expect(again.isFailure, isTrue);
  });

  test('registration otp flow creates profile and session', () async {
    final start = await repository.startRegistration(
      fullName: 'سارة محمد',
      phone: '07901234567',
      secretCode: '123456',
    );
    expect(start.isSuccess, isTrue);
    final challenge = start.valueOrNull!;
    expect(challenge.debugOtp, isNotNull);
    expect(challenge.debugOtp!.length, 6);

    final verify = await repository.verifyOtp(
      challengeId: challenge.challengeId,
      otp: challenge.debugOtp!,
      purpose: challenge.purpose,
      fullName: 'سارة محمد',
      phone: '+9647901234567',
      secretCode: '123456',
    );
    expect(verify.isSuccess, isTrue);
    expect(verify.valueOrNull, isA<RegistrationVerified>());

    final session = (verify.valueOrNull! as RegistrationVerified).session;
    expect(session.user.fullName, 'سارة محمد');
    expect(session.user.phone, '+9647901234567');
    expect(session.user.accountType.name, 'user');
    expect(session.user.accountStatus.name, 'active');
    expect(session.user.phoneVerified, isTrue);

    final restored = await repository.restoreSession();
    expect(restored.valueOrNull?.user.id, session.user.id);

    await repository.signOut();
    final afterSignOut = await repository.restoreSession();
    expect(afterSignOut.valueOrNull, isNull);
  });

  test('rejects invalid otp and allows resend', () async {
    final start = await repository.startRegistration(
      fullName: 'علي',
      phone: '07801234567',
      secretCode: 'abcdef',
    );
    final challenge = start.valueOrNull!;

    final wrong = await repository.verifyOtp(
      challengeId: challenge.challengeId,
      otp: '000000',
      purpose: challenge.purpose,
      fullName: 'علي',
      phone: '+9647801234567',
      secretCode: 'abcdef',
    );
    expect(wrong.isFailure, isTrue);

    final resent = await repository.resendOtp(
      challengeId: challenge.challengeId,
    );
    expect(resent.isSuccess, isTrue);
    expect(resent.valueOrNull!.debugOtp, isNotNull);
  });

  test('sign in with wrong credentials fails for unregistered phone', () async {
    final result = await repository.signInWithPhoneAndPassword(
      phone: '07909999999',
      secretCode: 'wrong1',
    );
    expect(result.isFailure, isTrue);
    expect(result.failureOrNull<PhoneNotRegisteredFailure>(), isNotNull);
  });

  test('password reset flow', () async {
    final start = await repository.startRegistration(
      fullName: 'محمود',
      phone: '07701234567',
      secretCode: 'oldpass',
    );
    final regChallenge = start.valueOrNull!;
    await repository.verifyOtp(
      challengeId: regChallenge.challengeId,
      otp: regChallenge.debugOtp!,
      purpose: regChallenge.purpose,
      fullName: 'محمود',
      phone: '+9647701234567',
      secretCode: 'oldpass',
    );
    await repository.signOut();

    final resetStart = await repository.requestPasswordReset(
      phone: '07701234567',
    );
    expect(resetStart.isSuccess, isTrue);
    final otpChallenge = resetStart.valueOrNull!;

    final verified = await repository.verifyOtp(
      challengeId: otpChallenge.challengeId,
      otp: otpChallenge.debugOtp!,
      purpose: otpChallenge.purpose,
    );
    expect(verified.valueOrNull, isA<PasswordResetOtpVerified>());

    final reset = await repository.resetPassword(
      challengeId: otpChallenge.challengeId,
      newSecretCode: 'newpass',
    );
    expect(reset.isSuccess, isTrue);

    final login = await repository.signInWithPhoneAndPassword(
      phone: '07701234567',
      secretCode: 'newpass',
    );
    expect(login.isSuccess, isTrue);
  });

  test('phone already exists', () async {
    final start = await repository.startRegistration(
      fullName: 'نورة',
      phone: '07501234567',
      secretCode: '123456',
    );
    final challenge = start.valueOrNull!;
    await repository.verifyOtp(
      challengeId: challenge.challengeId,
      otp: challenge.debugOtp!,
      purpose: challenge.purpose,
      fullName: 'نورة',
      phone: '+9647501234567',
      secretCode: '123456',
    );

    final again = await repository.startRegistration(
      fullName: 'نورة ٢',
      phone: '07501234567',
      secretCode: '123456',
    );
    expect(again.isFailure, isTrue);
    expect(again.failureOrNull<PhoneAlreadyExistsFailure>(), isNotNull);
  });
}
