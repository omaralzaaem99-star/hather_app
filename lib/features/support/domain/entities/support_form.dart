import 'package:equatable/equatable.dart';

class SupportFormSummary extends Equatable {
  const SupportFormSummary({
    required this.id,
    required this.title,
    this.description,
    required this.sortOrder,
  });

  final String id;
  final String title;
  final String? description;
  final int sortOrder;

  factory SupportFormSummary.fromJson(Map<String, dynamic> json) {
    return SupportFormSummary(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: _nullableString(json['description']),
      sortOrder: _asInt(json['sort_order']),
    );
  }

  static String? _nullableString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  List<Object?> get props => [id, title, description, sortOrder];
}

class SupportFormField extends Equatable {
  const SupportFormField({
    required this.id,
    required this.fieldKey,
    required this.label,
    required this.fieldType,
    this.placeholder,
    required this.isRequired,
    required this.sortOrder,
    this.options = const [],
  });

  final String id;
  final String fieldKey;
  final String label;
  final String fieldType;
  final String? placeholder;
  final bool isRequired;
  final int sortOrder;
  final List<String> options;

  bool get isText => fieldType == 'text';
  bool get isTextArea => fieldType == 'textarea';
  bool get isSelect => fieldType == 'select';

  factory SupportFormField.fromJson(Map<String, dynamic> json) {
    return SupportFormField(
      id: json['id']?.toString() ?? '',
      fieldKey: json['field_key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      fieldType: json['field_type']?.toString() ?? 'text',
      placeholder: _nullableString(json['placeholder']),
      isRequired: json['is_required'] == true,
      sortOrder: _asInt(json['sort_order']),
      options: _parseOptions(json['options']),
    );
  }

  static List<String> _parseOptions(Object? value) {
    if (value is List) {
      return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  static String? _nullableString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  List<Object?> get props => [
        id,
        fieldKey,
        label,
        fieldType,
        placeholder,
        isRequired,
        sortOrder,
        options,
      ];
}

class SupportFormDetail extends Equatable {
  const SupportFormDetail({
    required this.id,
    required this.title,
    this.description,
    required this.fields,
  });

  final String id;
  final String title;
  final String? description;
  final List<SupportFormField> fields;

  factory SupportFormDetail.fromJson(Map<String, dynamic> json) {
    final rawFields = json['fields'];
    final fields = <SupportFormField>[];
    if (rawFields is List) {
      for (final item in rawFields) {
        if (item is Map<String, dynamic>) {
          fields.add(SupportFormField.fromJson(item));
        } else if (item is Map) {
          fields.add(SupportFormField.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return SupportFormDetail(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: _nullableString(json['description']),
      fields: fields,
    );
  }

  static String? _nullableString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  @override
  List<Object?> get props => [id, title, description, fields];
}
