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

    if (!interceptor.isPersist) {
      _interceptors.remove(interceptor);
    }
  }
}

typedef dynamic ExceptionThrower();

class Interceptor {
  final RequestMatcher _matcher;

  Map<String, String> replayHeaders;
  int statusCode;
  dynamic body;
  Function exception;

  bool _isPersist = false;
  bool _isDone = false;
  bool _isSync = true;
  Completer _completer;

  Interceptor(this._matcher);

  bool get isDone => _isDone;

  bool _registered = false;

  _register() {
    if (_registered) {
      throw AlreadyRegistered(this);
    }

    _registered = true;
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

  bool get isPersist => _isPersist;

  void replay(int statusCode, dynamic body, {Map<String, String> headers}) {
    this.statusCode = statusCode;
    this.body = body;
    this.replayHeaders = headers;
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

    if (!_registered) {
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

  complete() => _completer?.complete();
}

Future whenCompleted(Interceptor interceptor) async {
  if (!interceptor._isSync) {
    interceptor._completer = Completer();
    return interceptor._completer.future;
  }
}
