import '../../../core/utils/phone_number_formatter.dart';
import '../domain/entities/account_enums.dart';
import '../data/models/auth_session_model.dart';
import '../data/models/auth_user_model.dart';

/// Test credentials helper for bypassing authentication during QA & preview testing.
/// Matches requested credentials:
/// Phone: 07742150942
/// Password: aa1234@ (and aa1234)
class TestAuthCredentials {
  const TestAuthCredentials._();

  static const String phoneLocal = '07742150942';
  static const String phoneE164 = '+9647742150942';
  static const String defaultPassword = 'aa1234@';
  static const String fallbackPassword = 'aa1234';
  static const String testUserId = '07742150-9420-4000-8000-077421509420';

  /// Returns true if the phone matches 07742150942 in any valid representation
  /// (local 07742150942, 7742150942, or international +9647742150942).
  static bool isTestPhone(String? phone) {
    if (phone == null || phone.isEmpty) return false;
    final digits = PhoneNumberFormatter.digitsOnly(phone);
    return digits == '07742150942' ||
        digits == '7742150942' ||
        digits == '9647742150942';
  }

  /// Returns true if the password matches aa1234@ or aa1234 (case-insensitive, trimmed).
  static bool isTestPassword(String? secretCode) {
    if (secretCode == null || secretCode.isEmpty) return false;
    final clean = secretCode.trim().toLowerCase();
    return clean == 'aa1234@' ||
        clean == 'aa1234' ||
        clean == '.aa1234@' ||
        clean == 'aa1234@.' ||
        clean == '.aa1234';
  }

  /// Returns true if both phone and password match the test credentials.
  static bool isTestAccount({
    required String? phone,
    required String? secretCode,
  }) {
    return isTestPhone(phone) && isTestPassword(secretCode);
  }

  /// Creates a mock active user session that allows full navigation and testing.
  static AuthSessionModel createMockSession({String? phone}) {
    final now = DateTime.now().toUtc();
    final actualPhone = phone != null && phone.isNotEmpty
        ? (PhoneNumberFormatter.normalizeToE164(phone) ?? phoneE164)
        : phoneE164;

    final user = AuthUserModel(
      id: testUserId,
      fullName: 'مستخدم تجريبي (حاضر)',
      phone: actualPhone,
      accountType: AccountType.user,
      accountStatus: AccountStatus.active,
      phoneVerified: true,
      createdAt: now.subtract(const Duration(days: 30)),
      updatedAt: now,
    );

    return AuthSessionModel(
      accessToken: 'test-bypass-access-token-$phoneLocal',
      refreshToken: 'test-bypass-refresh-token-$phoneLocal',
      user: user,
      expiresAt: now.add(const Duration(days: 365)),
    );
  }
}
