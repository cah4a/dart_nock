import 'interceptor.dart';

class NockScope {
  final String _baseUrl;

  NockScope(this._baseUrl);

  Interceptor _when(String method, dynamic path, dynamic data, {bool generateAuto = true}) => Interceptor(
        RequestMatcher(
          method,
          UriMatcher(_baseUrl, path),
          BodyMatcher(data),
        ),
      generateAuto: generateAuto,
      );

  Interceptor get(path, {bool autoHead = true}) => _when('get', path, null, generateAuto: autoHead);

  Interceptor post(path, [data]) => _when('post', path, data);

  Interceptor put(path, [data]) => _when('put', path, data);

  Interceptor delete(path, [data]) => _when('delete', path, data);

  Interceptor patch(path, [data]) => _when('patch', path, data);

  Interceptor head(path, [data]) => _when('head', path, data);
}
