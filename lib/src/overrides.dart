import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:nock/src/http_headers.dart';

import 'interceptor.dart';
import 'exceptions.dart';

class NockOverrides extends HttpOverrides {
  static void init() {
    HttpOverrides.global = NockOverrides();
  }

  @override
  HttpClient createHttpClient(SecurityContext context) {
    return MockClient();
  }
}

class MockClient implements HttpClient {
  bool autoUncompress;
  Duration connectionTimeout;
  Duration idleTimeout;
  int maxConnectionsPerHost;
  String userAgent;

  @override
  @override
  Future<HttpClientRequest> openUrl(String method, Uri uri) async {
    return MockHttpClientRequest(
      method,
      uri,
      MockHttpHeaders('1.1', defaultPortForScheme: uri.port),
    );
  }

  @override
  Future<HttpClientRequest> open(
      String method, String host, int port, String path) {
    const int hashMark = 0x23;
    const int questionMark = 0x3f;
    int fragmentStart = path.length;
    int queryStart = path.length;
    for (int i = path.length - 1; i >= 0; i--) {
      var char = path.codeUnitAt(i);
      if (char == hashMark) {
        fragmentStart = i;
        queryStart = i;
      } else if (char == questionMark) {
        queryStart = i;
      }
    }
    String query;
    if (queryStart < fragmentStart) {
      query = path.substring(queryStart + 1, fragmentStart);
      path = path.substring(0, queryStart);
    }
    Uri uri =
        Uri(scheme: "http", host: host, port: port, path: path, query: query);
    return openUrl(method, uri);
  }

  Future<HttpClientRequest> get(String host, int port, String path) =>
      open("get", host, port, path);

  Future<HttpClientRequest> getUrl(Uri url) => openUrl("get", url);

  Future<HttpClientRequest> post(String host, int port, String path) =>
      open("post", host, port, path);

  Future<HttpClientRequest> postUrl(Uri url) => openUrl("post", url);

  Future<HttpClientRequest> put(String host, int port, String path) =>
      open("put", host, port, path);

  Future<HttpClientRequest> putUrl(Uri url) => openUrl("put", url);

  Future<HttpClientRequest> delete(String host, int port, String path) =>
      open("delete", host, port, path);

  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl("delete", url);

  Future<HttpClientRequest> head(String host, int port, String path) =>
      open("head", host, port, path);

  Future<HttpClientRequest> headUrl(Uri url) => openUrl("head", url);

  Future<HttpClientRequest> patch(String host, int port, String path) =>
      open("patch", host, port, path);

  Future<HttpClientRequest> patchUrl(Uri url) => openUrl("patch", url);

  @override
  void addCredentials(
      Uri url, String realm, HttpClientCredentials credentials) {
    // TODO: implement addCredentials
  }

  @override
  void addProxyCredentials(
      String host, int port, String realm, HttpClientCredentials credentials) {
    // TODO: implement addProxyCredentials
  }

  @override
  set authenticate(
      Future<bool> Function(Uri url, String scheme, String realm) f) {
    // TODO: implement authenticate
  }

  @override
  set authenticateProxy(
      Future<bool> Function(String host, int port, String scheme, String realm)
          f) {
    // TODO: implement authenticateProxy
  }

  @override
  set badCertificateCallback(
      bool Function(X509Certificate cert, String host, int port) callback) {
    // TODO: implement badCertificateCallback
  }

  @override
  void close({bool force = false}) => null;

  @override
  set findProxy(String Function(Uri url) f) => null;
}

class MockHttpClientRequest extends HttpClientRequest {
  final String method;
  final Uri uri;
  final HttpHeaders headers;
  final body = <int>[];

  Encoding encoding;

  MockHttpClientRequest(this.method, this.uri, this.headers);

  @override
  Future<HttpClientResponse> get done async {
    final interceptor = registry.match(this);

    if (interceptor == null) {
      throw NetConnectionNotAllowed(this, registry.pendingMocks);
    }

    registry.completed(interceptor);

    if (interceptor.exception != null) {
      throw interceptor.exception();
    }

    final headers = MockHttpHeaders('1.1');
    interceptor.replyHeaders?.forEach((key, value) => headers.add(key, value));

    return MockHttpClientResponse(
      headers,
      interceptor.statusCode,
      interceptor.content,
    );
  }

  @override
  void add(List<int> data) {
    body.addAll(data);
  }

  @override
  void addError(Object error, [StackTrace stackTrace]) {
    // what should we do with that?
  }

  @override
  void abort([Object exception, StackTrace stackTrace]) {
      // what should we do with that?
  }

  @override
  Future addStream(Stream<List<int>> stream) async {
    await stream.forEach(add);
  }

  @override
  Future<HttpClientResponse> close() => done;

  @override
  HttpConnectionInfo get connectionInfo => null;

  @override
  List<Cookie> get cookies => [];

  @override
  Future flush() {
    // nuftodo
    return null;
  }

  @override
  void write(Object obj) {
    add(obj.toString().codeUnits);
  }

  @override
  void writeAll(Iterable objects, [String separator = ""]) {
    objects.forEach(write);
  }

  @override
  void writeCharCode(int charCode) {
    body.add(charCode);
  }

  @override
  void writeln([Object obj = ""]) {
    write(obj.toString() + "\n");
  }
}

class MockHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  final HttpHeaders headers;
  final int statusCode;
  final List<int> content;

  MockHttpClientResponse(
    this.headers,
    this.statusCode,
    this.content,
  ) {
    headers.add(HttpHeaders.contentLengthHeader, content.length.toString());
  }

  @override
  // TODO: implement certificate
  X509Certificate get certificate => null;

  @override
  // TODO: implement connectionInfo
  HttpConnectionInfo get connectionInfo => null;

  @override
  int get contentLength => content.length;

  @override
  List<Cookie> get cookies => [];

  @override
  Future<Socket> detachSocket() async => null;

  @override
  bool get isRedirect => false;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event) onData,
      {Function onError, void Function() onDone, bool cancelOnError}) {
    return Stream.fromIterable([content]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  bool get persistentConnection => true;

  @override
  String get reasonPhrase {
    // fucking copy-paste from dart sources
    switch (statusCode) {
      case HttpStatus.continue_:
        return "Continue";
      case HttpStatus.switchingProtocols:
        return "Switching Protocols";
      case HttpStatus.ok:
        return "OK";
      case HttpStatus.created:
        return "Created";
      case HttpStatus.accepted:
        return "Accepted";
      case HttpStatus.nonAuthoritativeInformation:
        return "Non-Authoritative Information";
      case HttpStatus.noContent:
        return "No Content";
      case HttpStatus.resetContent:
        return "Reset Content";
      case HttpStatus.partialContent:
        return "Partial Content";
      case HttpStatus.multipleChoices:
        return "Multiple Choices";
      case HttpStatus.movedPermanently:
        return "Moved Permanently";
      case HttpStatus.found:
        return "Found";
      case HttpStatus.seeOther:
        return "See Other";
      case HttpStatus.notModified:
        return "Not Modified";
      case HttpStatus.useProxy:
        return "Use Proxy";
      case HttpStatus.temporaryRedirect:
        return "Temporary Redirect";
      case HttpStatus.badRequest:
        return "Bad Request";
      case HttpStatus.unauthorized:
        return "Unauthorized";
      case HttpStatus.paymentRequired:
        return "Payment Required";
      case HttpStatus.forbidden:
        return "Forbidden";
      case HttpStatus.notFound:
        return "Not Found";
      case HttpStatus.methodNotAllowed:
        return "Method Not Allowed";
      case HttpStatus.notAcceptable:
        return "Not Acceptable";
      case HttpStatus.proxyAuthenticationRequired:
        return "Proxy Authentication Required";
      case HttpStatus.requestTimeout:
        return "Request Time-out";
      case HttpStatus.conflict:
        return "Conflict";
      case HttpStatus.gone:
        return "Gone";
      case HttpStatus.lengthRequired:
        return "Length Required";
      case HttpStatus.preconditionFailed:
        return "Precondition Failed";
      case HttpStatus.requestEntityTooLarge:
        return "Request Entity Too Large";
      case HttpStatus.requestUriTooLong:
        return "Request-URI Too Long";
      case HttpStatus.unsupportedMediaType:
        return "Unsupported Media Type";
      case HttpStatus.requestedRangeNotSatisfiable:
        return "Requested range not satisfiable";
      case HttpStatus.expectationFailed:
        return "Expectation Failed";
      case HttpStatus.internalServerError:
        return "Internal Server Error";
      case HttpStatus.notImplemented:
        return "Not Implemented";
      case HttpStatus.badGateway:
        return "Bad Gateway";
      case HttpStatus.serviceUnavailable:
        return "Service Unavailable";
      case HttpStatus.gatewayTimeout:
        return "Gateway Time-out";
      case HttpStatus.httpVersionNotSupported:
        return "Http Version not supported";
      default:
        return "Status $statusCode";
    }
  }

  @override
  Future<HttpClientResponse> redirect([
    String method,
    Uri url,
    bool followLoops,
  ]) async =>
      this;

  @override
  List<RedirectInfo> get redirects => [];

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
}
