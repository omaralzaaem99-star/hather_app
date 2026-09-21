import 'package:equatable/equatable.dart';

enum SupportRequestStatus {
  newRequest('new'),
  inProgress('in_progress'),
  resolved('resolved'),
  closed('closed');

  const SupportRequestStatus(this.value);

  final String value;

  static SupportRequestStatus? fromValue(String? raw) {
    if (raw == null) return null;
    for (final status in SupportRequestStatus.values) {
      if (status.value == raw) return status;
    }
    return null;
  }
}

class SupportRequestSummary extends Equatable {
  const SupportRequestSummary({
    required this.id,
    required this.requestNumber,
    required this.formTitle,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final int requestNumber;
  final String formTitle;
  final SupportRequestStatus status;
  final DateTime? createdAt;

  factory SupportRequestSummary.fromJson(Map<String, dynamic> json) {
    return SupportRequestSummary(
      id: json['id']?.toString() ?? '',
      requestNumber: _asInt(json['request_number']),
      formTitle: json['form_title']?.toString() ?? '',
      status: SupportRequestStatus.fromValue(json['status']?.toString()) ??
          SupportRequestStatus.newRequest,
      createdAt: _parseDate(json['created_at']),
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  @override
  List<Object?> get props => [id, requestNumber, formTitle, status, createdAt];
}

class SupportRequestAnswer extends Equatable {
  const SupportRequestAnswer({
    required this.label,
    required this.fieldKey,
    required this.value,
    this.fieldType = 'text',
  });

  final String label;
  final String fieldKey;
  final String value;
  final String fieldType;

  factory SupportRequestAnswer.fromJson(Map<String, dynamic> json) {
    return SupportRequestAnswer(
      label: json['label']?.toString() ?? '',
      fieldKey: json['field_key']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      fieldType: json['field_type']?.toString() ?? 'text',
    );
  }

  @override
  List<Object?> get props => [label, fieldKey, value, fieldType];
}

class SupportRequestDetail extends Equatable {
  const SupportRequestDetail({
    required this.id,
    required this.requestNumber,
    required this.formTitle,
    required this.status,
    required this.answers,
    this.adminReply,
    this.repliedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final int requestNumber;
  final String formTitle;
  final SupportRequestStatus status;
  final List<SupportRequestAnswer> answers;
  final String? adminReply;
  final DateTime? repliedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasAdminReply => adminReply?.trim().isNotEmpty == true;

  factory SupportRequestDetail.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'];
    final answers = <SupportRequestAnswer>[];
    if (payload is List) {
      for (final item in payload) {
        if (item is Map<String, dynamic>) {
          answers.add(SupportRequestAnswer.fromJson(item));
        } else if (item is Map) {
          answers.add(
            SupportRequestAnswer.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return SupportRequestDetail(
      id: json['id']?.toString() ?? '',
      requestNumber: SupportRequestSummary._asInt(json['request_number']),
      formTitle: json['form_title']?.toString() ?? '',
      status: SupportRequestStatus.fromValue(json['status']?.toString()) ??
          SupportRequestStatus.newRequest,
      answers: answers,
      adminReply: json['admin_reply']?.toString(),
      repliedAt: SupportRequestSummary._parseDate(json['replied_at']),
      createdAt: SupportRequestSummary._parseDate(json['created_at']),
      updatedAt: SupportRequestSummary._parseDate(json['updated_at']),
    );
  }

  @override
  List<Object?> get props => [
        id,
        requestNumber,
        formTitle,
        status,
        answers,
        adminReply,
        repliedAt,
        createdAt,
        updatedAt,
      ];
}

class SupportSubmissionResult extends Equatable {
  const SupportSubmissionResult({
    required this.id,
    required this.requestNumber,
    required this.formTitle,
    required this.status,
  });

  final String id;
  final int requestNumber;
  final String formTitle;
  final SupportRequestStatus status;

  factory SupportSubmissionResult.fromJson(Map<String, dynamic> json) {
    return SupportSubmissionResult(
      id: json['id']?.toString() ?? '',
      requestNumber: SupportRequestSummary._asInt(json['request_number']),
      formTitle: json['form_title']?.toString() ?? '',
      status: SupportRequestStatus.fromValue(json['status']?.toString()) ??
          SupportRequestStatus.newRequest,
    );
  }

  @override
  List<Object?> get props => [id, requestNumber, formTitle, status];
}
