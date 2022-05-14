library nock;

import 'src/overrides.dart';
import 'src/scope.dart';
import 'src/interceptor.dart';

export 'src/exceptions.dart';
export 'src/interceptor.dart' show Interceptor;

final Nock nock = _Nock();

abstract class Nock implements NockScope {
  void init();

  NockScope call(String base);

  void cleanAll();

  set defaultBase(String value);

  Iterable<Interceptor> get pendingMocks;

  Iterable<Interceptor> get activeMocks;
}

class _Nock implements Nock {
  String? _defaultBase;

  @override
  void init([String? defaultBase]) {
    NockOverrides.init();
  }

  @override
  set defaultBase(String value) => _defaultBase = value;

  @override
  void cleanAll() => registry.cleanAll();

  @override
  NockScope call(String base) => NockScope(base);

  @override
  Iterable<Interceptor> get pendingMocks => registry.pendingMocks;

  @override
  Iterable<Interceptor> get activeMocks => registry.activeMocks;

  NockScope get _defaultScope {
    assert(_defaultBase != null);
    return call(_defaultBase!);
  }

  @override
  Interceptor get(path, {bool autoHead = true}) => _defaultScope.get(path, autoHead: autoHead);

  @override
  Interceptor post(path, [data]) => _defaultScope.post(path, data);

  @override
  Interceptor put(path, [data]) => _defaultScope.put(path, data);

  @override
  Interceptor delete(path, [data]) => _defaultScope.delete(path, data);

  @override
  Interceptor patch(path, [data]) => _defaultScope.patch(path, data);

  @override
  Interceptor head(path, [data]) => _defaultScope.head(path, data);
}
