import 'interceptor.dart';

class NockScope {
  final String _baseUrl;

  NockScope(this._baseUrl);

  Interceptor _when(String method, dynamic path, dynamic data) => Interceptor(
        RequestMatcher(
          method,
          UriMatcher(_baseUrl, path),
          BodyMatcher(data),
        ),
      );

  Interceptor get(path) => _when('get', path, null);

  Interceptor post(path, [data]) => _when('post', path, data);

  Interceptor put(path, [data]) => _when('put', path, data);

  Interceptor delete(path, [data]) => _when('delete', path, data);

  Interceptor patch(path, [data]) => _when('patch', path, data);

  Interceptor head(path, [data]) => _when('head', path, data);
}
