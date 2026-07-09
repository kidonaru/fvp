import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fvp/src/disposable_event_controller.dart';

void main() {
  group('DisposableEventController', () {
    test('close前のイベントを配送する', () async {
      final controller = DisposableEventController<int>();
      final events = <int>[];
      final subscription = controller.stream.listen(events.add);

      controller.add(1);
      await Future<void>.delayed(Duration.zero);

      expect(events, [1]);
      await subscription.cancel();
      controller.close();
    });

    test('close後のイベントとエラーを無視する', () {
      final controller = DisposableEventController<int>();

      controller.close();

      expect(() => controller.add(1), returnsNormally);
      expect(
        () => controller.addError(StateError('テスト用エラー')),
        returnsNormally,
      );
      expect(controller.isClosed, isTrue);
    });

    test('closeを複数回呼べる', () {
      final controller = DisposableEventController<int>();

      controller.close();

      expect(controller.close, returnsNormally);
      expect(controller.isClosed, isTrue);
    });

    test('close前に開始した遅延処理のイベントをclose後に無視する', () async {
      final controller = DisposableEventController<int>();
      final completer = Completer<int>();
      final events = <int>[];
      final subscription = controller.stream.listen(events.add);
      final delayedAdd = completer.future.then(controller.add);

      controller.close();
      completer.complete(1);
      await delayedAdd;

      expect(events, isEmpty);
      await subscription.cancel();
    });
  });
}
