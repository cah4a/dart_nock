import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

import 'package:collection/collection.dart';

import 'overrides.dart' show MockHttpClientRequest;
import 'exceptions.dart';

part 'request_matcher.dart';

final Registry registry = Registry();

class Registry {
  final _interceptors = <Interceptor>[];

  void cleanAll() => _interceptors.clear();

  Iterable<Interceptor> get pendingMocks => _interceptors.where(
        (interceptor) => !interceptor.isDone,
      );

  Iterable<Interceptor> get activeMocks => _interceptors;

  void add(Interceptor interceptor) => _interceptors.add(interceptor);

  void remove(Interceptor interceptor) {
    _interceptors.remove(interceptor);
    interceptor._onReply?.close();
  }

  Interceptor match(HttpClientRequest request) {
    final interceptor = _interceptors.firstWhere(
      (interceptor) => interceptor._matcher.match(request),
      orElse: () => null,
    );

    if (interceptor == null) {
      return null;
    }

    return interceptor;
  }

  void completed(Interceptor interceptor) {
    interceptor._isDone = true;
    interceptor._onReply?.add(null);

    if (!interceptor.isPersist) {
      remove(interceptor);
    }
  }

  contains(Interceptor interceptor) => _interceptors.contains(interceptor);
}

typedef dynamic ExceptionThrower();

class Interceptor {
  final RequestMatcher _matcher;

  Map<String, String> replyHeaders;
  int statusCode;
  dynamic body;
  Function exception;

  bool _isPersist = false;
  bool _isDone = false;
  bool _isRegistered = false;
  bool _isCanceled = false;

  StreamController _onReply;

  Interceptor(this._matcher);

  bool get isDone => _isDone;

  bool get isActive => registry.contains(this);

  bool get isPersist => _isPersist;

  _register() {
    if (_isCanceled) {
      throw AlreadyCanceled(this);
    }

    if (_isRegistered) {
      throw AlreadyRegistered(this);
    }

    _isRegistered = true;
    registry.add(this);
  }

  void throwing(ExceptionThrower thrower) {
    exception = thrower;
    _register();
  }

  void throwNetworkError() {
    exception = () => SocketException.closed();
    _register();
  }

  void throwHandshakeError() {
    exception = () => HandshakeException();
    _register();
  }

  void throwCertificateError() {
    exception = () => CertificateException();
    _register();
  }

  void persist([bool enabled = true]) => _isPersist = enabled;

  void query(dynamic query) => _matcher.uri.expected = query;

  void headers(Map<String, dynamic> headers) =>
      _matcher.headers.expected = headers;

  /// Type problems.
  /// Will be removed in next versions.
  /// Use [reply] method.
  @deprecated
  void replay(int statusCode, dynamic body, {Map<String, String> headers}) {
    reply(statusCode, body, headers: headers);
  }

  void reply(int statusCode, dynamic body, {Map<String, String> headers}) {
    this.statusCode = statusCode;
    this.body = body;
    this.replyHeaders = headers;
    _register();
  }

  List<int> get content {
    var body = this.body;

    if (body is List<int>) {
      return body;
    }

    if (body is Map || body is List) {
      body = json.encode(body);
    }

    if (body is String) {
      return utf8.encode(body);
    }

    return <int>[];
  }

  @override
  String toString() {
    String def = "${_matcher.method} ${_matcher.uri.definition}";

    if (_matcher.uri._query != null) {
      def += " +q";
    }

    if (_matcher.body.expected != null) {
      def += " +b";
    }

    if (!_isRegistered) {
      return def;
    }

    if (exception != null) {
      return def + " throws ${exception()}";
    }

    def += " -> $statusCode";

    if (body != null) {
      def += " $body";
    }

    return def;
  }

  void cancel() {
    _isCanceled = true;

    if (_isRegistered) {
      registry.remove(this);
      _onReply?.close();
    }
  }

  void onReply(callback()) {
    if (!isActive) {
      throw MockIsNotActive(this);
    }

    _onReply ??= StreamController.broadcast();
    _onReply.stream.listen((_) {
      callback();
    });
  }
}
