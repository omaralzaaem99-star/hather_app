import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/core/notifications/push_device_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('PushDeviceRepository', () {
    test('isEnabled does not require injected client', () {
      final repo = PushDeviceRepository();
      expect(repo.isEnabled, isA<bool>());
    });

    test('sanitizePushSyncError hides raw SQL details', () {
      expect(
        sanitizePushSyncError(
          const PostgrestException(
            message:
                'insert into push_device_tokens violates foreign key constraint',
            code: '42501',
          ),
        ),
        'not authenticated',
      );
      expect(
        sanitizePushSyncError(
          const PostgrestException(
            message: 'installation_id and fcm_token required',
            code: '22023',
          ),
        ),
        'invalid parameters',
      );
      expect(
        sanitizePushSyncError(StateError('not authenticated')),
        'not authenticated',
      );
    });
  });
}
