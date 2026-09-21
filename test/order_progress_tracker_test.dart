import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/features/delivery/presentation/widgets/order_progress_tracker.dart';

void main() {
  group('OrderProgressTracker states', () {
    test('pending: step 1 done, step 2 current', () {
      final states = OrderProgressTracker.statesFor('pending');
      expect(states[0], OrderProgressStepState.completed);
      expect(states[1], OrderProgressStepState.current);
      expect(states[2], OrderProgressStepState.upcoming);
      expect(states[3], OrderProgressStepState.upcoming);
      expect(OrderProgressTracker.currentStepFor('pending'), 2);
    });

    test('active: steps 1-2 done, step 3 current', () {
      final states = OrderProgressTracker.statesFor('active');
      expect(states[0], OrderProgressStepState.completed);
      expect(states[1], OrderProgressStepState.completed);
      expect(states[2], OrderProgressStepState.current);
      expect(states[3], OrderProgressStepState.upcoming);
      expect(OrderProgressTracker.currentStepFor('active'), 3);
    });

    test('completed: all done', () {
      final states = OrderProgressTracker.statesFor('completed');
      expect(
        states.every((s) => s == OrderProgressStepState.completed),
        isTrue,
      );
      expect(OrderProgressTracker.currentStepFor('completed'), 4);
    });

    test('cancelled: only created completed, no fake delivery', () {
      final states = OrderProgressTracker.statesFor('cancelled');
      expect(states[0], OrderProgressStepState.completed);
      expect(states[1], OrderProgressStepState.upcoming);
      expect(states[2], OrderProgressStepState.upcoming);
      expect(states[3], OrderProgressStepState.upcoming);
      expect(OrderProgressTracker.currentStepFor('cancelled'), isNull);
    });
  });
}
