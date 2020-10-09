part of 'interceptor.dart';

Function deepEq = const DeepCollectionEquality().equals;

typedef bool MatcherFn<T>(T uri);
typedef bool BodyRawMatchFn(List<int> body, ContentType contentType);

class RequestMatcher {
  final String method;
  final UriMatcher uri;
  final BodyMatcher body;
  final HeadersMatcher headers = HeadersMatcher();

  RequestMatcher(this.method, this.uri, this.body);

  bool match(MockHttpClientRequest request) {
    return method.toUpperCase() == request.method.toUpperCase() &&
        uri.match(request.uri) &&
        headers.match(request.headers) &&
        body.match(request.body, request.headers.contentType);
  }
}

class BodyMatcher {
  dynamic expected;

  BodyMatcher(this.expected);

  bool match(List<int> request, ContentType contentType) {
    if (expected == null) {
      return request.isEmpty;
    }

    if (expected is BodyRawMatchFn) {
      return expected(request, contentType);
    }

    if (expected is MatcherFn) {
      return expected(request);
    }

    final data = _content(request, contentType);

    if (contentType?.mimeType == "application/x-www-form-urlencoded") {
      return _matchUrlEncoded(Uri(query: data));
    }

    if (expected is RegExp && data is String) {
      return expected.hasMatch(data);
    }

    if (expected is Matcher) {
      return expected.matches(data, {});
    }

    return equals(expected).matches(data, {});
  }

  dynamic _content(List<int> request, ContentType contentType) {
    if (contentType == null || contentType.primaryType == "text") {
      return utf8.decode(request);
    }

    switch (contentType?.mimeType ?? "text/plain") {
      case "application/x-www-form-urlencoded":
        return utf8.decode(request);
      case "application/json":
        return json.decode(utf8.decode(request));
      default:
        return request;
    }
  }

  bool _matchUrlEncoded(Uri uri) {
    if (expected is MatcherFn<Map<String, List<String>>>) {
      return expected(uri.queryParametersAll);
    }

    if (expected is MatcherFn<Map<String, String>>) {
      return expected(uri.queryParameters);
    }

    if (expected is Map<String, List>) {
      return equals(expected).matches(uri.queryParametersAll, {});
    }

    if (expected is Map<String, dynamic>) {
      return equals(expected).matches(uri.queryParameters, {});
    }

    return false;
  }
}

class UriMatcher {
  String definition;
  String _base;
  dynamic _path;
  dynamic _query;

  set expected(dynamic query) {
    if (query is! String &&
        query is! Map<String, dynamic> &&
        query is! Matcher &&
        query is! MatcherFn<Map<String, String>> &&
        query is! MatcherFn<Map<String, List<String>>>) {
      throw UnknownQueryMatcherType(query);
    }

    _query = query;
  }

  UriMatcher(this._base, path) {
    if (path is! Uri &&
        path is! String &&
        path is! RegExp &&
        path is! Matcher &&
        path is! MatcherFn<Uri>) {
      throw UnknownUrlMatcherType(path);
    }

    if (path is String) {
      _path = Uri.parse(_base + path);
      definition = _path.toString();
    } else {
      definition = "$_base/$_path";
      _path = path;
    }
  }

  bool match(Uri uri) {
    if (!uri.toString().startsWith(_base)) {
      return false;
    }

    if (_path is MatcherFn<Uri>) {
      return _path(uri);
    }

    if (_path is Matcher && _query == null) {
      if (_path.matches(uri.toString().replaceAll(_base, ""), {})) {
        // case when query parameters was matching inside _path matcher
        return true;
      }
    }

    if (!_matchUrl(uri)) {
      return false;
    }

    return _matchQuery(uri);
  }

  bool _matchQuery(Uri uri) {
    final query = _getExpectedQuery();

    if (!uri.hasQuery && query == null) {
      return true;
    }

    if (query is Matcher) {
      return query.matches(uri.queryParametersAll, {});
    }

    if (query is Map<String, List>) {
      return equals(query).matches(uri.queryParametersAll, {});
    }

    if (query is Map) {
      return equals(query).matches(uri.queryParameters, {});
    }

    if (query is MatcherFn<Map<String, List<String>>>) {
      return query(uri.queryParametersAll);
    }

    if (query is MatcherFn<Map<String, String>>) {
      return query(uri.queryParameters);
    }

    return false;
  }

  dynamic _getExpectedQuery() {
    if (_query == null && _path is Uri) {
      return _path.queryParametersAll;
    }

    if (_query is String) {
      return Uri(query: _query).queryParametersAll;
    }

    return _query;
  }

  bool _matchUrl(Uri uri) {
    final normalizedUri = _normalize(uri);

    if (_path is Uri) {
      return normalizedUri == _normalize(_path);
    }

    if (_path is Matcher) {
      return _path.matches(normalizedUri.toString().replaceAll(_base, ""), {});
    }

    if (_path is RegExp) {
      return _path.hasMatch(normalizedUri.toString().replaceAll(_base, ""));
    }

    return false;
  }
}

class HeadersMatcher {
  Map<String, dynamic> expected;

  HeadersMatcher([this.expected]);

  bool match(HttpHeaders headers) {
    if (expected == null) {
      return true;
    }

    return expected.keys.every(
      (header) => _matchHeader(expected[header], headers[header]),
    );
  }

  bool _matchHeader(expected, List<String> actual) {
    if (actual == null) {
      return expected == null;
    }

    if (expected is Matcher) {
      return expected.matches(actual, {}) ||
          actual.any(
            (val) => expected.matches(val, {}),
          );
    }

    if (expected is String) {
      return actual.contains(expected);
    }

    if (expected is List) {
      return equals(expected).matches(actual, {});
    }

    return false;
  }
}

Uri _normalize(Uri uri) => Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.port,
      path: uri.path,
    );
