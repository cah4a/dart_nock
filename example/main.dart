import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:nock/nock.dart';

void main() {
  setUpAll(() {
    nock.init();
  });

  setUp(() {
    nock.cleanAll();
  });

  test('example', () async {
    final interceptor = nock('http://localhost/api').get('/users')
      ..reply(
        200,
        'result',
      );

    final response = await http.get(Uri.parse('http://localhost/api/users'));

    expect(interceptor.isDone, true);
    expect(response.statusCode, 200);
    expect(response.body, 'result');
  });
}
