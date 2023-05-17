import 'package:nock/src/overrides.dart';

class NetConnectionNotAllowed extends Error {
  final MockHttpClientRequest request;
  final Iterable pendingMocks;

  NetConnectionNotAllowed(this.request, this.pendingMocks);

  @override
  String toString() {
    return 'Request was: $_request\n$_pending';
  }

  String get _request => '${request.method} ${request.uri}';

  String get _pending {
    if (pendingMocks.isEmpty) {
      return 'No pending mocks';
    }

    return 'Pending mocks: ' + pendingMocks.toString();
  }
}

class UnknownUrlMatcherType implements Exception {
  final url;

  UnknownUrlMatcherType(this.url);

  @override
  String toString() => 'Unknown url matcher type ${url.runtimeType}';
}

class AlreadyRegistered implements Exception {
  final dynamic interceptor;

  AlreadyRegistered(this.interceptor);

  @override
  String toString() => 'Request $interceptor already registered';
}

class AlreadyCanceled implements Exception {
  final dynamic interceptor;

  AlreadyCanceled(this.interceptor);

  @override
  String toString() => 'Request $interceptor was canceled';
}

class MockIsNotActive implements Exception {
  final dynamic interceptor;

  MockIsNotActive(this.interceptor);

  @override
  String toString() => 'Request $interceptor is not active';
}

class UnknownBodyType implements Exception {
  final body;

  UnknownBodyType(this.body);

  @override
  String toString() => 'Unknown body type ${body.runtimeType}';
}

class UnknownQueryMatcherType implements Exception {
  final query;

  UnknownQueryMatcherType(this.query);

  @override
  String toString() => 'Unknown query matcher type ${query.runtimeType}';
}
