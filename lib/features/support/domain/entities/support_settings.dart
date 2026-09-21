import 'package:equatable/equatable.dart';

/// Public support configuration returned by `get_support_settings()`.
class SupportSettings extends Equatable {
  const SupportSettings({
    required this.whatsappEnabled,
    this.whatsappNumber,
    required this.phoneEnabled,
    this.phoneNumber,
    required this.emailEnabled,
    this.emailAddress,
    this.supportMessage,
  });

  final bool whatsappEnabled;
  final String? whatsappNumber;
  final bool phoneEnabled;
  final String? phoneNumber;
  final bool emailEnabled;
  final String? emailAddress;
  final String? supportMessage;

  factory SupportSettings.empty() {
    return const SupportSettings(
      whatsappEnabled: false,
      phoneEnabled: false,
      emailEnabled: false,
    );
  }

  factory SupportSettings.fromJson(Map<String, dynamic> json) {
    return SupportSettings(
      whatsappEnabled: json['whatsapp_enabled'] == true,
      whatsappNumber: _nullableString(json['whatsapp_number']),
      phoneEnabled: json['phone_enabled'] == true,
      phoneNumber: _nullableString(json['phone_number']),
      emailEnabled: json['email_enabled'] == true,
      emailAddress: _nullableString(json['email_address']),
      supportMessage: _nullableString(json['support_message']),
    );
  }

  bool get hasWhatsappChannel =>
      whatsappEnabled && whatsappNumber != null && whatsappNumber!.isNotEmpty;

  bool get hasPhoneChannel =>
      phoneEnabled && phoneNumber != null && phoneNumber!.isNotEmpty;

  bool get hasEmailChannel =>
      emailEnabled && emailAddress != null && emailAddress!.isNotEmpty;

  bool get hasAnyChannel =>
      hasWhatsappChannel || hasPhoneChannel || hasEmailChannel;

  static String? _nullableString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  @override
  List<Object?> get props => [
        whatsappEnabled,
        whatsappNumber,
        phoneEnabled,
        phoneNumber,
        emailEnabled,
        emailAddress,
        supportMessage,
      ];
}
