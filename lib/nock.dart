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
  String _defaultBase;

  void init([String defaultBase]) {
    NockOverrides.init();
  }

  set defaultBase(String value) => _defaultBase = value;

  void cleanAll() => registry.cleanAll();

  NockScope call(String base) => NockScope(base);

  Iterable<Interceptor> get pendingMocks => registry.pendingMocks;

  Iterable<Interceptor> get activeMocks => registry.activeMocks;

  NockScope get _defaultScope {
    assert(_defaultBase != null);
    return call(_defaultBase);
  }

  Interceptor get(path) => _defaultScope.get(path);

  Interceptor post(path, [data]) => _defaultScope.post(path, data);

  Interceptor put(path, [data]) => _defaultScope.put(path, data);

  Interceptor delete(path, [data]) => _defaultScope.delete(path, data);

  Interceptor patch(path, [data]) => _defaultScope.patch(path, data);

  Interceptor head(path, [data]) => _defaultScope.head(path, data);
}
