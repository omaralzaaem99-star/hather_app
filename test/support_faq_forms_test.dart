import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/features/support/domain/entities/support_faq.dart';
import 'package:hather_app/features/support/domain/entities/support_form.dart';
import 'package:hather_app/features/support/domain/entities/support_request.dart';

void main() {
  group('SupportFaq', () {
    test('parses from json', () {
      final faq = SupportFaq.fromJson({
        'id': 'f1',
        'question': 'كيف ألغي طلبي؟',
        'answer': 'من صفحة الطلبات',
        'sort_order': 2,
      });
      expect(faq.question, 'كيف ألغي طلبي؟');
      expect(faq.sortOrder, 2);
    });
  });

  group('SupportFormDetail', () {
    test('parses fields from json', () {
      final form = SupportFormDetail.fromJson({
        'id': 'form1',
        'title': 'مشكلة في الطلب',
        'description': 'وصف',
        'fields': [
          {
            'id': 'fld1',
            'field_key': 'order_id',
            'label': 'رقم الطلب',
            'field_type': 'text',
            'is_required': true,
            'sort_order': 0,
          },
          {
            'id': 'fld2',
            'field_key': 'issue_type',
            'label': 'نوع المشكلة',
            'field_type': 'select',
            'is_required': true,
            'sort_order': 1,
            'options': ['تأخير', 'مشكلة أخرى'],
          },
        ],
      });

      expect(form.fields.length, 2);
      expect(form.fields.first.isRequired, isTrue);
      expect(form.fields.last.options, ['تأخير', 'مشكلة أخرى']);
    });
  });

  group('SupportRequestDetail', () {
    test('parses admin reply without admin_note', () {
      final detail = SupportRequestDetail.fromJson({
        'id': 'r1',
        'request_number': 125,
        'form_title': 'مشكلة في الطلب',
        'status': 'resolved',
        'payload': [
          {
            'label': 'رقم الطلب',
            'field_key': 'order_id',
            'value': '12345',
            'field_type': 'text',
          },
        ],
        'admin_reply': 'تمت مراجعة المشكلة.',
        'replied_at': '2026-08-22T15:40:00Z',
        'created_at': '2026-08-22T14:00:00Z',
      });

      expect(detail.hasAdminReply, isTrue);
      expect(detail.adminReply, 'تمت مراجعة المشكلة.');
      expect(detail.answers.single.value, '12345');
      expect(detail.status, SupportRequestStatus.resolved);
    });
  });
}
