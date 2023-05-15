import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:nock/nock.dart';

void main() {
  late HttpClient client;

  setUpAll(nock.init);

  setUp(() {
    nock.cleanAll();
    client = HttpClient();
  });

  test('straight forward', () async {
    nock('http://127.0.0.1').get('/subpath').reply(
          200,
          'result',
        );

    final request = await client.getUrl(Uri.parse('http://127.0.0.1/subpath'));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).toList();

    expect(response.statusCode, 200);
    expect(body.join(), 'result');
  });

  test('using matchers for urls', () async {
    nock('http://127.0.0.1').get(startsWith('/subpath?ref=')).reply(
          200,
          'result',
        );

    final request = await client
        .getUrl(Uri.parse('http://127.0.0.1/subpath?ref=XpKeURAAACzK17lv'));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).toList();

    expect(response.statusCode, 200);
    expect(body.join(), 'result');
  });

  test('connection not allowed', () async {
    nock('http://127.0.0.1').get('/subpath').reply(
          200,
          'something',
        );

    {
      final request = await client.getUrl(Uri.parse('http://127.0.0.1/other'));
      expect(request.close(), throwsA(TypeMatcher<NetConnectionNotAllowed>()));
    }

    {
      final request =
          await client.postUrl(Uri.parse('http://127.0.0.1/subpath'));
      expect(request.close(), throwsA(TypeMatcher<NetConnectionNotAllowed>()));
    }
  });

  test('autoremove', () async {
    final result = {'foo': 'bar'};

    nock('http://127.0.0.1').get('/subpath').reply(
          200,
          result,
        );

    final request = await client.getUrl(Uri.parse('http://127.0.0.1/subpath'));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).toList();

    expect(response.statusCode, 200);
    expect(body.join(), json.encode(result));

    {
      final request =
          await client.getUrl(Uri.parse('http://127.0.0.1/subpath'));
      expect(request.close(), throwsA(TypeMatcher<NetConnectionNotAllowed>()));
    }

    {
      final request =
          await client.postUrl(Uri.parse('http://127.0.0.1/subpath'));
      expect(request.close(), throwsA(TypeMatcher<NetConnectionNotAllowed>()));
    }
  });

  test('cancel', () async {
    final result = {'foo': 'bar'};

    final interceptor = nock('http://127.0.0.1').get('/subpath')
      ..reply(
        200,
        result,
      );

    interceptor.cancel();

    final request = await client.getUrl(Uri.parse('http://127.0.0.1/subpath'));

    expect(
      request.close(),
      throwsA(TypeMatcher<NetConnectionNotAllowed>()),
    );
  });

  test('on complete', () async {
    final result = {'foo': 'bar'};

    final interceptor = nock('http://127.0.0.1').get('/subpath')
      ..reply(
        200,
        result,
      );

    var isCompleted = false;

    interceptor.onReply(() {
      isCompleted = true;
    });

    final request = await client.getUrl(Uri.parse('http://127.0.0.1/subpath'));

    expect(isCompleted, false);
    await request.close();
    expect(isCompleted, true);
  });

  test('persist', () async {
    final result = {'foo': 'bar'};

    final scope = nock('http://127.0.0.1').get('/subpath')
      ..persist()
      ..reply(
        200,
        result,
      );

    {
      final request =
          await client.getUrl(Uri.parse('http://127.0.0.1/subpath'));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).toList();

      expect(response.statusCode, 200);
      expect(body.join(), json.encode(result));
    }

    scope.persist(false);

    {
      final request =
          await client.getUrl(Uri.parse('http://127.0.0.1/subpath'));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).toList();

      expect(response.statusCode, 200);
      expect(body.join(), json.encode(result));
    }

    {
      final request =
          await client.getUrl(Uri.parse('http://127.0.0.1/subpath'));
      expect(request.close(), throwsA(TypeMatcher<NetConnectionNotAllowed>()));
    }
  });

  test('query', () async {
    nock('http://127.0.0.1').get('/subpath')
      ..query({'a': '1'})
      ..reply(
        200,
        'something',
      );

    final uri = Uri.parse('http://127.0.0.1/subpath');

    {
      final req = await client.getUrl(uri);

      expect(
        req.close(),
        throwsA(TypeMatcher<NetConnectionNotAllowed>()),
      );
    }

    {
      final uri = Uri.parse('http://127.0.0.1/subpath?a=1');
      final req = await client.getUrl(uri);
      final response = await req.close();
      final body = await response.transform(utf8.decoder).toList();

      expect(body.join(), 'something');
    }
  });

  test('post match', () async {
    nock('http://127.0.0.1').post('/subpath', anything)
      ..persist()
      ..reply(
        200,
        'something',
      );

    final uri = Uri.parse('http://127.0.0.1/subpath');

    {
      final req = await client.postUrl(uri);
      final response = await req.close();
      final body = await response.transform(utf8.decoder).toList();
      expect(body.join(), 'something');
    }

    {
      final uri = Uri.parse('http://127.0.0.1/subpath');
      final req = await client.postUrl(uri);

      req.headers.contentType = ContentType.json;
      req.write(json.encode({'spongebob': 'square pants'}));

      final response = await req.close();
      final body = await response.transform(utf8.decoder).toList();

      expect(body.join(), 'something');
    }
  });

  test('body match', () async {
    final data = {'data': 1234};

    nock('http://127.0.0.1').post('/subpath', data).reply(
          200,
          'something',
        );

    final uri = Uri.parse('http://127.0.0.1/subpath');

    {
      final req = await client.postUrl(uri);

      expect(
        req.close(),
        throwsA(TypeMatcher<NetConnectionNotAllowed>()),
      );
    }

    {
      final uri = Uri.parse('http://127.0.0.1/subpath');
      final req = await client.postUrl(uri);

      req.headers.contentType = ContentType.json;
      req.write(json.encode(data));

      final response = await req.close();
      final body = await response.transform(utf8.decoder).toList();

      expect(body.join(), 'something');
    }
  });

  test('request headers', () async {
    nock('http://127.0.0.1').get('/subpath')
      ..headers({'foo': 'bar'})
      ..reply(
        200,
        'baz',
      );

    final uri = Uri.parse('http://127.0.0.1/subpath');

    {
      final req = await client.getUrl(uri);
      req.headers.add('foo', 'bax');

      expect(
        req.close(),
        throwsA(TypeMatcher<NetConnectionNotAllowed>()),
      );
    }

    {
      final req = await client.getUrl(uri);
      req.headers.add('foo', 'bar');
      final response = await req.close();
      final body = await response.transform(utf8.decoder).toList();

      expect(body.join(), 'baz');
    }
  });

  test('reply headers', () async {
    nock('http://127.0.0.1').get('/subpath').reply(
      200,
      'foobar',
      headers: {'foo': 'bar'},
    );

    final uri = Uri.parse('http://127.0.0.1/subpath');
    final req = await client.getUrl(uri);
    final response = await req.close();
    final body = await response.transform(utf8.decoder).toList();

    expect(body.join(), 'foobar');
    expect(response.headers.value('foo'), 'bar');
  });

  test('exception', () async {
    nock('http://127.0.0.1').get('/subpath').throwing(() => 'my exception');

    final uri = Uri.parse('http://127.0.0.1/subpath');
    final req = await client.getUrl(uri);

    expect(req.close(), throwsA('my exception'));
  });
}
