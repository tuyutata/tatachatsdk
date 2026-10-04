/// 按会话键串行执行密码学操作，不同会话仍可并行。
final class SerialExecutor {
  final Map<String, Future<void>> _tails = <String, Future<void>>{};

  Future<T> run<T>(String key, Future<T> Function() operation) {
    if (key.isEmpty) throw ArgumentError.value(key, 'key', '会话键不能为空');
    final previous = _tails[key] ?? Future<void>.value();
    final current = previous.then<T>(
      (_) => operation(),
      onError: (_, __) => operation(),
    );
    final tail = current.then<void>((_) {}, onError: (_, __) {});
    _tails[key] = tail;
    tail.whenComplete(() {
      if (identical(_tails[key], tail)) _tails.remove(key);
    });
    return current;
  }
}
