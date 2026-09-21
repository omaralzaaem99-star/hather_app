import 'package:equatable/equatable.dart';

class SupportFaq extends Equatable {
  const SupportFaq({
    required this.id,
    required this.question,
    required this.answer,
    required this.sortOrder,
  });

  final String id;
  final String question;
  final String answer;
  final int sortOrder;

  factory SupportFaq.fromJson(Map<String, dynamic> json) {
    return SupportFaq(
      id: json['id']?.toString() ?? '',
      question: json['question']?.toString() ?? '',
      answer: json['answer']?.toString() ?? '',
      sortOrder: _asInt(json['sort_order']),
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  List<Object?> get props => [id, question, answer, sortOrder];
}
