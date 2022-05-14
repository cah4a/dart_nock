import 'dart:collection';
import 'dart:convert';
import 'dart:io';

/// copy-pasted from dart lib
/// see [feature](https://github.com/dart-lang/sdk/issues/36675)
class MockHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _headers;
  final String protocolVersion;

  final _mutable = true; // Are the headers currently mutable?
  List<String>? _noFoldingHeaders;

  int _contentLength = -1;
  bool _persistentConnection = true;
  bool _chunkedTransferEncoding = false;

  String? _host;
  int? _port;

  final int _defaultPortForScheme;

  MockHttpHeaders(this.protocolVersion,
      {int defaultPortForScheme = HttpClient.defaultHttpPort,
      MockHttpHeaders? initialHeaders})
      : _headers = <String, List<String>>{},
        _defaultPortForScheme = defaultPortForScheme {
    if (initialHeaders != null) {
      initialHeaders._headers.forEach((name, value) => _headers[name] = value);
      _contentLength = initialHeaders._contentLength;
      _persistentConnection = initialHeaders._persistentConnection;
      _chunkedTransferEncoding = initialHeaders._chunkedTransferEncoding;
      _host = initialHeaders._host;
      _port = initialHeaders._port;
    }
    if (protocolVersion == '1.0') {
      _persistentConnection = false;
      _chunkedTransferEncoding = false;
    }
  }

  @override
  List<String>? operator [](String name) => _headers[name];

  @override
  String? value(String name) {
    name = name;
    final values = _headers[name];
    if (values == null) return null;
    if (values.length > 1) {
      throw HttpException('More than one value for header $name');
    }
    return values[0];
  }

  @override
  void add(String name, value, {bool preserveHeaderCase = false}) {
    _checkMutable();
    _addAll(_validateField(name), value);
  }

  void _addAll(String name, value) {
    assert(name == _validateField(name));
    if (value is Iterable) {
      for (var v in value) {
        _add(name, _validateValue(v));
      }
    } else {
      _add(name, _validateValue(value));
    }
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _checkMutable();
    name = _validateField(name);
    _headers.remove(name);
    if (name == HttpHeaders.transferEncodingHeader) {
      _chunkedTransferEncoding = false;
    }
    _addAll(name, value);
  }

  @override
  void remove(String name, Object value) {
    _checkMutable();
    name = _validateField(name);
    value = _validateValue(value);
    List<String?>? values = _headers[name];
    if (values != null) {
      var index = values.indexOf(value as String?);
      if (index != -1) {
        values.removeRange(index, index + 1);
      }
      if (values.isEmpty) _headers.remove(name);
    }
    if (name == HttpHeaders.transferEncodingHeader && value == 'chunked') {
      _chunkedTransferEncoding = false;
    }
  }

  @override
  void removeAll(String name) {
    _checkMutable();
    name = _validateField(name);
    _headers.remove(name);
  }

  @override
  void forEach(void Function(String name, List<String> values) f) {
    _headers.forEach(f);
  }

  @override
  void noFolding(String name) {
    if (_noFoldingHeaders == null) {
      _noFoldingHeaders = <String>[name];
    } else {
      _noFoldingHeaders!.add(name);
    }
  }

  @override
  bool get persistentConnection => _persistentConnection;

  @override
  set persistentConnection(bool persistentConnection) {
    _checkMutable();
    if (persistentConnection == _persistentConnection) return;
    if (persistentConnection) {
      if (protocolVersion == '1.1') {
        remove(HttpHeaders.connectionHeader, 'close');
      } else {
        if (_contentLength == -1) {
          throw HttpException(
            "Trying to set 'Connection: Keep-Alive' on HTTP 1.0 headers with no ContentLength",
          );
        }
        add(HttpHeaders.connectionHeader, 'keep-alive');
      }
    } else {
      if (protocolVersion == '1.1') {
        add(HttpHeaders.connectionHeader, 'close');
      } else {
        remove(HttpHeaders.connectionHeader, 'keep-alive');
      }
    }
    _persistentConnection = persistentConnection;
  }

  @override
  int get contentLength => _contentLength;

  @override
  set contentLength(int contentLength) {
    _checkMutable();
    if (protocolVersion == '1.0' &&
        persistentConnection &&
        contentLength == -1) {
      throw HttpException(
        "Trying to clear ContentLength on HTTP 1.0 headers with 'Connection: Keep-Alive' set",
      );
    }
    if (_contentLength == contentLength) return;
    _contentLength = contentLength;
    if (_contentLength >= 0) {
      if (chunkedTransferEncoding) chunkedTransferEncoding = false;
      _set(HttpHeaders.contentLengthHeader, contentLength.toString());
    } else {
      removeAll(HttpHeaders.contentLengthHeader);
      if (protocolVersion == '1.1') {
        chunkedTransferEncoding = true;
      }
    }
  }

  @override
  bool get chunkedTransferEncoding => _chunkedTransferEncoding;

  @override
  set chunkedTransferEncoding(bool chunkedTransferEncoding) {
    _checkMutable();
    if (chunkedTransferEncoding && protocolVersion == '1.0') {
      throw HttpException(
          "Trying to set 'Transfer-Encoding: Chunked' on HTTP 1.0 headers");
    }
    if (chunkedTransferEncoding == _chunkedTransferEncoding) return;
    if (chunkedTransferEncoding) {
      List<String?>? values = _headers[HttpHeaders.transferEncodingHeader];
      if ((values == null || values.last != 'chunked')) {
        // Headers does not specify chunked encoding - add it if set.
        _addValue(HttpHeaders.transferEncodingHeader, 'chunked');
      }
      contentLength = -1;
    } else {
      // Headers does specify chunked encoding - remove it if not set.
      remove(HttpHeaders.transferEncodingHeader, 'chunked');
    }
    _chunkedTransferEncoding = chunkedTransferEncoding;
  }

  @override
  String? get host => _host;

  @override
  set host(String? host) {
    _checkMutable();
    _host = host;
    _updateHostHeader();
  }

  @override
  int? get port => _port;

  @override
  set port(int? port) {
    _checkMutable();
    _port = port;
    _updateHostHeader();
  }

  @override
  DateTime? get ifModifiedSince {
    final values = _headers[HttpHeaders.ifModifiedSinceHeader];
    if (values != null) {
      try {
        return HttpDate.parse(values[0]);
      } on Exception {
        return null;
      }
    }
    return null;
  }

  @override
  set ifModifiedSince(DateTime? ifModifiedSince) {
    _checkMutable();

    if (ifModifiedSince == null) {
      _headers.remove(HttpHeaders.ifModifiedSinceHeader);
    } else {
      // Format "ifModifiedSince" header with date in Greenwich Mean Time (GMT).
      final formatted = HttpDate.format(ifModifiedSince.toUtc());
      _set(HttpHeaders.ifModifiedSinceHeader, formatted);
    }
  }

  @override
  DateTime? get date {
    final values = _headers[HttpHeaders.dateHeader];
    if (values != null) {
      try {
        return HttpDate.parse(values[0]);
      } on Exception {
        return null;
      }
    }
    return null;
  }

  @override
  set date(DateTime? date) {
    _checkMutable();
    if (date == null) {
      _headers.remove(HttpHeaders.dateHeader);
    } else {
      // Format "DateTime" header with date in Greenwich Mean Time (GMT).
      final formatted = HttpDate.format(date.toUtc());
      _set(HttpHeaders.dateHeader, formatted);
    }
  }

  @override
  DateTime? get expires {
    final values = _headers[HttpHeaders.expiresHeader];

    if (values != null) {
      try {
        return HttpDate.parse(values[0]);
      } on Exception {
        return null;
      }
    }
    return null;
  }

  @override
  set expires(DateTime? expires) {
    _checkMutable();
    if (expires == null) {
      _headers.remove(HttpHeaders.expiresHeader);
    } else {
      // Format "Expires" header with date in Greenwich Mean Time (GMT).
      final formatted = HttpDate.format(expires.toUtc());
      _set(HttpHeaders.expiresHeader, formatted);
    }
  }

  @override
  ContentType? get contentType {
    var values = _headers['content-type'];
    if (values != null) {
      return ContentType.parse(values[0]);
    } else {
      return null;
    }
  }

  @override
  set contentType(ContentType? contentType) {
    _checkMutable();
    _set(HttpHeaders.contentTypeHeader, contentType.toString());
  }

  @override
  void clear() {
    _checkMutable();
    _headers.clear();
    _contentLength = -1;
    _persistentConnection = true;
    _chunkedTransferEncoding = false;
    _host = null;
    _port = null;
  }

  // [name] must be a lower-case version of the name.
  void _add(String name, value) {
    assert(name == _validateField(name));
    // Use the length as index on what method to call. This is notable
    // faster than computing hash and looking up in a hash-map.
    switch (name.length) {
      case 4:
        if (HttpHeaders.dateHeader == name) {
          _addDate(name, value);
          return;
        }
        if (HttpHeaders.hostHeader == name) {
          _addHost(name, value);
          return;
        }
        break;
      case 7:
        if (HttpHeaders.expiresHeader == name) {
          _addExpires(name, value);
          return;
        }
        break;
      case 10:
        if (HttpHeaders.connectionHeader == name) {
          _addConnection(name, value);
          return;
        }
        break;
      case 12:
        if (HttpHeaders.contentTypeHeader == name) {
          _addContentType(name, value);
          return;
        }
        break;
      case 14:
        if (HttpHeaders.contentLengthHeader == name) {
          _addContentLength(name, value);
          return;
        }
        break;
      case 17:
        if (HttpHeaders.transferEncodingHeader == name) {
          _addTransferEncoding(name, value);
          return;
        }
        if (HttpHeaders.ifModifiedSinceHeader == name) {
          _addIfModifiedSince(name, value);
          return;
        }
    }
    _addValue(name, value);
  }

  void _addContentLength(String name, value) {
    if (value is int) {
      contentLength = value;
    } else if (value is String) {
      contentLength = int.parse(value);
    } else {
      throw HttpException("Unexpected type for header named $name");
    }
  }

  void _addTransferEncoding(String name, value) {
    if (value == "chunked") {
      chunkedTransferEncoding = true;
    } else {
      _addValue(HttpHeaders.transferEncodingHeader, value);
    }
  }

  void _addDate(String name, value) {
    if (value is DateTime) {
      date = value;
    } else if (value is String) {
      _set(HttpHeaders.dateHeader, value);
    } else {
      throw HttpException("Unexpected type for header named $name");
    }
  }

  void _addExpires(String name, value) {
    if (value is DateTime) {
      expires = value;
    } else if (value is String) {
      _set(HttpHeaders.expiresHeader, value);
    } else {
      throw HttpException("Unexpected type for header named $name");
    }
  }

  void _addIfModifiedSince(String name, value) {
    if (value is DateTime) {
      ifModifiedSince = value;
    } else if (value is String) {
      _set(HttpHeaders.ifModifiedSinceHeader, value);
    } else {
      throw HttpException("Unexpected type for header named $name");
    }
  }

  void _addHost(String name, value) {
    if (value is String) {
      int pos = value.indexOf(":");
      if (pos == -1) {
        _host = value;
        _port = HttpClient.defaultHttpPort;
      } else {
        if (pos > 0) {
          _host = value.substring(0, pos);
        } else {
          _host = null;
        }
        if (pos + 1 == value.length) {
          _port = HttpClient.defaultHttpPort;
        } else {
          try {
            _port = int.parse(value.substring(pos + 1));
          } on FormatException {
            _port = null;
          }
        }
      }
      _set(HttpHeaders.hostHeader, value);
    } else {
      throw HttpException("Unexpected type for header named $name");
    }
  }

  void _addConnection(String name, value) {
    var lowerCaseValue = value;
    if (lowerCaseValue == 'close') {
      _persistentConnection = false;
    } else if (lowerCaseValue == 'keep-alive') {
      _persistentConnection = true;
    }
    _addValue(name, value);
  }

  void _addContentType(String name, value) {
    _set(HttpHeaders.contentTypeHeader, value);
  }

  void _addValue(String name, Object value) {
    var values = _headers[name];
    if (values == null) {
      values = <String>[];
      _headers[name] = values;
    }
    if (value is DateTime) {
      values.add(HttpDate.format(value));
    } else if (value is String) {
      values.add(value);
    } else {
      values.add(_validateValue(value.toString()));
    }
  }

  void _set(String name, String value) {
    assert(name == _validateField(name));
    var values = <String>[];
    _headers[name] = values;
    values.add(value);
  }

  void _checkMutable() {
    if (!_mutable) throw HttpException("HTTP headers are not mutable");
  }

  void _updateHostHeader() {
    var host = _host;
    if (host != null) {
      final defaultPort = _port == null || _port == _defaultPortForScheme;
      _set('host', defaultPort ? host : '$host:$_port');
    }
  }

  bool _foldHeader(String name) {
    if (name == HttpHeaders.setCookieHeader ||
        (_noFoldingHeaders != null && _noFoldingHeaders!.contains(name))) {
      return false;
    }
    return true;
  }

  @override
  String toString() {
    final sb = StringBuffer();
    _headers.forEach((String name, List<String?> values) {
      sb
        ..write(name)
        ..write(': ');
      final fold = _foldHeader(name);
      for (var i = 0; i < values.length; i++) {
        if (i > 0) {
          if (fold) {
            sb.write(', ');
          } else {
            sb
              ..write('\n')
              ..write(name)
              ..write(': ');
          }
        }
        sb.write(values[i]);
      }
      sb.write('\n');
    });
    return sb.toString();
  }

  // ignore: unused_element
  List<Cookie> _parseCookies() {
    // Parse a Cookie header value according to the rules in RFC 6265.
    var cookies = <Cookie>[];
    void parseCookieString(String? s) {
      var index = 0;

      bool done() => index == -1 || index == s!.length;

      void skipWS() {
        while (!done()) {
          if (s![index] != ' ' && s[index] != '\t') return;
          index++;
        }
      }

      String parseName() {
        var start = index;
        while (!done()) {
          if (s![index] == ' ' || s[index] == '\t' || s[index] == '=') break;
          index++;
        }
        return s!.substring(start, index);
      }

      String parseValue() {
        var start = index;
        while (!done()) {
          if (s![index] == ' ' || s[index] == '\t' || s[index] == ';') break;
          index++;
        }
        return s!.substring(start, index);
      }

      bool expect(String expected) {
        if (done()) return false;
        if (s![index] != expected) return false;
        index++;
        return true;
      }

      while (!done()) {
        skipWS();
        if (done()) return;
        var name = parseName();
        skipWS();
        if (!expect('=')) {
          index = s!.indexOf(';', index);
          continue;
        }
        skipWS();
        var value = parseValue();
        try {
          cookies.add(_Cookie(name, value));
        } catch (_) {
          // Skip it, invalid cookie data.
        }
        skipWS();
        if (done()) return;
        if (!expect(';')) {
          index = s!.indexOf(';', index);
          continue;
        }
      }
    }

    final values = _headers[HttpHeaders.cookieHeader];
    if (values != null) {
      values.forEach((headerValue) => parseCookieString(headerValue));
    }
    return cookies;
  }

  static bool _isTokenChar(int byte) {
    return byte > 31 && byte < 128 && !_Const.SEPARATOR_MAP[byte];
  }

  static String _validateField(String field) {
    for (var i = 0; i < field.length; i++) {
      if (!_isTokenChar(field.codeUnitAt(i))) {
        throw FormatException(
          'Invalid HTTP header field name: ${json.encode(field)}',
        );
      }
    }
    return field.toLowerCase();
  }

  static dynamic _validateValue(value) {
    if (value is! String) return value;
    for (var i = 0; i < value.length; i++) {
      if (!_isValueChar(value.codeUnitAt(i))) {
        throw FormatException(
          'Invalid HTTP header field value: ${json.encode(value)}',
        );
      }
    }
    return value;
  }

  static bool _isValueChar(int byte) {
    return (byte > 31 && byte < 128) ||
        (byte == _CharCode.SP) ||
        (byte == _CharCode.HT);
  }
}

class _HeaderValue implements HeaderValue {
  String _value;
  Map<String, String?>? _parameters;
  Map<String, String?>? _unmodifiableParameters;

  _HeaderValue([this._value = '', Map<String, String>? parameters]) {
    if (parameters != null) {
      _parameters = Map<String, String>.from(parameters);
    }
  }

  static _HeaderValue parse(
    String value, {
    parameterSeparator = ';',
    valueSeparator,
    preserveBackslash = false,
  }) {
    // Parse the string.
    var result = _HeaderValue();
    result._parse(value, parameterSeparator, valueSeparator, preserveBackslash);
    return result;
  }

  @override
  String get value => _value;

  void _ensureParameters() {
    _parameters ??= <String, String>{};
  }

  @override
  Map<String, String?> get parameters {
    _ensureParameters();
    _unmodifiableParameters ??= UnmodifiableMapView(_parameters!);
    return _unmodifiableParameters!;
  }

  @override
  String toString() {
    final sb = StringBuffer();
    sb.write(_value);
    if (parameters.isNotEmpty) {
      _parameters!.forEach((String name, String? value) {
        sb
          ..write('; ')
          ..write(name)
          ..write('=')
          ..write(value);
      });
    }
    return sb.toString();
  }

  void _parse(
    String s,
    String parameterSeparator,
    String? valueSeparator,
    bool preserveBackslash,
  ) {
    var index = 0;

    bool done() => index == s.length;

    void skipWS() {
      while (!done()) {
        if (s[index] != ' ' && s[index] != '\t') return;
        index++;
      }
    }

    String parseValue() {
      var start = index;
      while (!done()) {
        if (s[index] == ' ' ||
            s[index] == '\t' ||
            s[index] == valueSeparator ||
            s[index] == parameterSeparator) break;
        index++;
      }
      return s.substring(start, index);
    }

    void expect(String expected) {
      if (done() || s[index] != expected) {
        throw HttpException('Failed to parse header value');
      }
      index++;
    }

    void maybeExpect(String expected) {
      if (s[index] == expected) index++;
    }

    void parseParameters() {
      final parameters = HashMap<String, String?>();
      _parameters = UnmodifiableMapView(parameters);

      String parseParameterName() {
        final start = index;
        while (!done()) {
          if (s[index] == ' ' ||
              s[index] == '\t' ||
              s[index] == '=' ||
              s[index] == parameterSeparator ||
              s[index] == valueSeparator) break;
          index++;
        }
        return s.substring(start, index);
      }

      String? parseParameterValue() {
        if (!done() && s[index] == '"') {
          // Parse quoted value.
          final sb = StringBuffer();
          index++;
          while (!done()) {
            if (s[index] == '\\') {
              if (index + 1 == s.length) {
                throw HttpException('Failed to parse header value');
              }
              if (preserveBackslash && s[index + 1] != '"') {
                sb.write(s[index]);
              }
              index++;
            } else if (s[index] == '"') {
              index++;
              break;
            }
            sb.write(s[index]);
            index++;
          }
          return sb.toString();
        } else {
          // Parse non-quoted value.
          var val = parseValue();
          return val == '' ? null : val;
        }
      }

      while (!done()) {
        skipWS();
        if (done()) return;
        final name = parseParameterName();
        skipWS();
        if (done()) {
          parameters[name] = null;
          return;
        }
        maybeExpect("=");
        skipWS();
        if (done()) {
          parameters[name] = null;
          return;
        }
        String? value = parseParameterValue();
        if (name == 'charset' && this is _ContentType && value != null) {
          // Charset parameter of ContentTypes are always lower-case.
          value = value;
        }
        parameters[name] = value;
        skipWS();
        if (done()) return;
        // TODO: Implement support for multi-valued parameters.
        if (s[index] == valueSeparator) return;
        expect(parameterSeparator);
      }
    }

    skipWS();
    _value = parseValue();
    skipWS();
    if (done()) return;
    maybeExpect(parameterSeparator);
    parseParameters();
  }
}

// ignore: unused_element
class _ContentType extends _HeaderValue implements ContentType {
  String _primaryType = "";
  String _subType = "";

  _ContentType(String primaryType, String subType, String charset,
      Map<String, String> parameters)
      : _primaryType = primaryType,
        _subType = subType,
        super("") {
    if (_primaryType == null) _primaryType = "";
    if (_subType == null) _subType = "";
    _value = "$_primaryType/$_subType";
    if (parameters != null) {
      _ensureParameters();
      parameters.forEach((String key, String value) {
        String lowerCaseKey = key;
        if (lowerCaseKey == "charset") {
          value = value;
        }
        this._parameters![lowerCaseKey] = value;
      });
    }
    if (charset != null) {
      _ensureParameters();
      this._parameters!["charset"] = charset;
    }
  }

  _ContentType._();

  static _ContentType parse(String value) {
    var result = _ContentType._();
    result._parse(value, ";", null, false);
    int index = result._value.indexOf("/");
    if (index == -1 || index == (result._value.length - 1)) {
      result._primaryType = result._value.trim();
      result._subType = "";
    } else {
      result._primaryType = result._value.substring(0, index).trim();
      result._subType = result._value.substring(index + 1).trim();
    }
    return result;
  }

  String get mimeType => '$primaryType/$subType';

  String get primaryType => _primaryType;

  String get subType => _subType;

  String? get charset => parameters["charset"];
}

class _Cookie implements Cookie {
  @override
  String name;
  @override
  String value;
  @override
  DateTime? expires;
  @override
  int? maxAge;
  @override
  String? domain;
  @override
  String? path;
  @override
  bool httpOnly = false;
  @override
  bool secure = false;

  _Cookie(this.name, this.value) {
    // Default value of httponly is true.
    httpOnly = true;
    _validate();
  }

  _Cookie.fromSetCookieValue(String value)
      : name = '',
        value = '' {
    // Parse the 'set-cookie' header value.
    _parseSetCookieValue(value);
  }

  // Parse a 'set-cookie' header value according to the rules in RFC 6265.
  void _parseSetCookieValue(String s) {
    var index = 0;

    bool done() => index == s.length;

    String parseName() {
      var start = index;
      while (!done()) {
        if (s[index] == "=") break;
        index++;
      }
      return s.substring(start, index).trim();
    }

    String parseValue() {
      var start = index;
      while (!done()) {
        if (s[index] == ";") break;
        index++;
      }
      return s.substring(start, index).trim();
    }

    // ignore: unused_element
    void expect(String expected) {
      if (done()) throw HttpException('Failed to parse header value [$s]');
      if (s[index] != expected) {
        throw HttpException('Failed to parse header value [$s]');
      }
      index++;
    }

    void parseAttributes() {
      String parseAttributeName() {
        var start = index;
        while (!done()) {
          if (s[index] == "=" || s[index] == ";") break;
          index++;
        }
        return s.substring(start, index).trim();
      }

      String parseAttributeValue() {
        var start = index;
        while (!done()) {
          if (s[index] == ";") break;
          index++;
        }
        return s.substring(start, index).trim();
      }

      while (!done()) {
        var name = parseAttributeName();
        var value = '';
        if (!done() && s[index] == '=') {
          index++; // Skip the = character.
          value = parseAttributeValue();
        }
        if (name == 'expires') {
          expires = _parseCookieDate(value);
        } else if (name == 'max-age') {
          maxAge = int.parse(value);
        } else if (name == 'domain') {
          domain = value;
        } else if (name == 'path') {
          path = value;
        } else if (name == 'httponly') {
          httpOnly = true;
        } else if (name == 'secure') {
          secure = true;
        }
        if (!done()) index++; // Skip the ; character
      }
    }

    name = parseName();
    if (done() || name.isEmpty) {
      throw HttpException('Failed to parse header value [$s]');
    }
    index++; // Skip the = character.
    value = parseValue();
    _validate();
    if (done()) return;
    index++; // Skip the ; character.
    parseAttributes();
  }

  // Parse a cookie date string.
  static DateTime _parseCookieDate(String date) {
    const monthsLowerCase = [
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec',
    ];

    var position = 0;

    void error() {
      throw HttpException('Invalid cookie date $date');
    }

    bool isEnd() => position == date.length;

    bool isDelimiter(String s) {
      final char = s.codeUnitAt(0);
      if (char == 0x09) return true;
      if (char >= 0x20 && char <= 0x2F) return true;
      if (char >= 0x3B && char <= 0x40) return true;
      if (char >= 0x5B && char <= 0x60) return true;
      if (char >= 0x7B && char <= 0x7E) return true;
      return false;
    }

    bool isNonDelimiter(String s) {
      final char = s.codeUnitAt(0);
      if (char >= 0x00 && char <= 0x08) return true;
      if (char >= 0x0A && char <= 0x1F) return true;
      if (char >= 0x30 && char <= 0x39) return true; // Digit
      if (char == 0x3A) return true; // ':'
      if (char >= 0x41 && char <= 0x5A) return true; // Alpha
      if (char >= 0x61 && char <= 0x7A) return true; // Alpha
      if (char >= 0x7F && char <= 0xFF) return true; // Alpha
      return false;
    }

    bool isDigit(String s) {
      final char = s.codeUnitAt(0);
      if (char > 0x2F && char < 0x3A) return true;
      return false;
    }

    int getMonth(String month) {
      if (month.length < 3) return -1;
      return monthsLowerCase.indexOf(month.substring(0, 3));
    }

    int toInt(String s) {
      int index = 0;
      for (; index < s.length && isDigit(s[index]); index++) {
        //
      }
      return int.parse(s.substring(0, index));
    }

    var tokens = [];
    while (!isEnd()) {
      while (!isEnd() && isDelimiter(date[position])) {
        position++;
      }
      final start = position;
      while (!isEnd() && isNonDelimiter(date[position])) {
        position++;
      }
      tokens.add(date.substring(start, position).toLowerCase());
      while (!isEnd() && isDelimiter(date[position])) {
        position++;
      }
    }

    String? timeStr;
    String? dayOfMonthStr;
    String? monthStr;
    String? yearStr;

    for (var token in tokens) {
      if (token.length < 1) continue;
      if (timeStr == null &&
          token.length >= 5 &&
          isDigit(token[0]) &&
          (token[1] == ':' || (isDigit(token[1]) && token[2] == ':'))) {
        timeStr = token;
      } else if (dayOfMonthStr == null && isDigit(token[0])) {
        dayOfMonthStr = token;
      } else if (monthStr == null && getMonth(token) >= 0) {
        monthStr = token;
      } else if (yearStr == null &&
          token.length >= 2 &&
          isDigit(token[0]) &&
          isDigit(token[1])) {
        yearStr = token;
      }
    }

    if (timeStr == null ||
        dayOfMonthStr == null ||
        monthStr == null ||
        yearStr == null) {
      error();
    }

    var year = toInt(yearStr!);
    if (year >= 70 && year <= 99) {
      year += 1900;
    } else if (year >= 0 && year <= 69) {
      year += 2000;
    }
    if (year < 1601) {
      error();
    }

    var dayOfMonth = toInt(dayOfMonthStr!);
    if (dayOfMonth < 1 || dayOfMonth > 31) error();

    var month = getMonth(monthStr!) + 1;

    var timeList = timeStr!.split(":");
    if (timeList.length != 3) error();
    var hour = toInt(timeList[0]);
    var minute = toInt(timeList[1]);
    var second = toInt(timeList[2]);
    if (hour > 23) error();
    if (minute > 59) error();
    if (second > 59) error();

    return DateTime.utc(year, month, dayOfMonth, hour, minute, second, 0);
  }

  String toString() {
    final sb = StringBuffer();
    sb
      ..write(name)
      ..write('=')
      ..write(value);
    if (expires != null) {
      sb
        ..write('; Expires=')
        ..write(HttpDate.format(expires!));
    }
    if (maxAge != null) {
      sb
        ..write('; Max-Age=')
        ..write(maxAge);
    }
    if (domain != null) {
      sb
        ..write('; Domain=')
        ..write(domain);
    }
    if (path != null) {
      sb
        ..write('; Path=')
        ..write(path);
    }
    if (secure) sb.write('; Secure');
    if (httpOnly) sb.write('; HttpOnly');
    return sb.toString();
  }

  void _validate() {
    const separators = [
      '(',
      ')',
      '<',
      '>',
      '@',
      ',',
      ';',
      ':',
      '\\',
      '"',
      '/',
      '[',
      ']',
      '?',
      '=',
      '{',
      '}',
    ];
    for (var i = 0; i < name.length; i++) {
      final codeUnit = name.codeUnits[i];
      if (codeUnit <= 32 || codeUnit >= 127 || separators.contains(name[i])) {
        throw FormatException(
            "Invalid character in cookie name, code unit: '$codeUnit'");
      }
    }

    if (value[0] == '"' && value[value.length - 1] == '"') {
      value = value.substring(1, value.length - 1);
    }
    for (var i = 0; i < value.length; i++) {
      final codeUnit = value.codeUnits[i];
      if (!(codeUnit == 0x21 ||
          (codeUnit >= 0x23 && codeUnit <= 0x2B) ||
          (codeUnit >= 0x2D && codeUnit <= 0x3A) ||
          (codeUnit >= 0x3C && codeUnit <= 0x5B) ||
          (codeUnit >= 0x5D && codeUnit <= 0x7E))) {
        throw FormatException(
            "Invalid character in cookie value, code unit: '$codeUnit'");
      }
    }
  }
}

// Frequently used character codes.
class _CharCode {
  static const int HT = 9;
  static const int LF = 10;
  static const int CR = 13;
  static const int SP = 32;
  static const int AMPERSAND = 38;
  static const int COMMA = 44;
  static const int DASH = 45;
  static const int SLASH = 47;
  static const int ZERO = 48;
  static const int ONE = 49;
  static const int COLON = 58;
  static const int SEMI_COLON = 59;
  static const int EQUAL = 61;
}

// Global constants.
class _Const {
  // Bytes for "HTTP".
  static const HTTP = [72, 84, 84, 80];

  // Bytes for "HTTP/1.".
  static const HTTP1DOT = [72, 84, 84, 80, 47, 49, 46];

  // Bytes for "HTTP/1.0".
  static const HTTP10 = [72, 84, 84, 80, 47, 49, 46, 48];

  // Bytes for "HTTP/1.1".
  static const HTTP11 = [72, 84, 84, 80, 47, 49, 46, 49];

  static const bool T = true;
  static const bool F = false;

  // Loopup-map for the following characters: '()<>@,;:\\"/[]?={} \t'.
  static const SEPARATOR_MAP = [
    F, F, F, F, F, F, F, F, F, T, F, F, F, F, F, F, F, F, F, F, F, F, F, F, //
    F, F, F, F, F, F, F, F, T, F, T, F, F, F, F, F, T, T, F, F, T, F, F, T, //
    F, F, F, F, F, F, F, F, F, F, T, T, T, T, T, T, T, F, F, F, F, F, F, F, //
    F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, T, T, T, F, F, //
    F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, //
    F, F, F, T, F, T, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, //
    F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, //
    F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, //
    F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, //
    F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, //
    F, F, F, F, F, F, F, F, F, F, F, F, F, F, F, F
  ];
}
