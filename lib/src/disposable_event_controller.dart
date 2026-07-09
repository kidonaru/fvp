import 'dart:async';

class DisposableEventController<T> {
  final StreamController<T> _controller = StreamController<T>();
  bool _isClosed = false;

  Stream<T> get stream => _controller.stream;

  bool get isClosed => _isClosed;

  void add(T event) {
    if (_isClosed) {
      return;
    }
    _controller.add(event);
  }

  void addError(Object error, [StackTrace? stackTrace]) {
    if (_isClosed) {
      return;
    }
    _controller.addError(error, stackTrace);
  }

  void close() {
    if (_isClosed) {
      return;
    }
    _isClosed = true;
    unawaited(_controller.close());
  }
}
