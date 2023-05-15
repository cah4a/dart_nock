import 'package:nock/src/interceptor.dart';
import 'package:test/test.dart';

void main() {
  final base = 'http://127.0.0.1';

  group('general', () {
    test('base', () {
      expect(
        UriMatcher(base, '/url').match(Uri.parse('http://127.0.0.2/url')),
        false,
      );

      expect(
        UriMatcher(base, '/url').match(Uri.parse('http://127.0.0.1/url')),
        true,
      );
    });
  });

  group('cases', () {
    final cases = [
      // String
      _Case(
        expected: '/url',
        actual: '/url',
        result: true,
      ),
      _Case(
        expected: '/url',
        actual: '/other',
        result: false,
      ),
      _Case(
        expected: '/url?',
        actual: '/url',
        result: true,
      ),
      // query
      _Case(
        expected: '/url?a=3',
        actual: '/url',
        result: false,
      ),
      _Case(
        expected: '/url?a=10',
        actual: '/url',
        query: 'b=123',
        result: false,
      ),
      _Case(
        expected: '/url?a=3&b=5',
        actual: '/url?b=5&a=3',
        result: true,
      ),
      _Case(
        expected: '/url',
        actual: '/url?a[]=3&a[]=5',
        query: {
          'a[]': ['3', '5']
        },
        result: true,
      ),
      // Regexp
      _Case(
        expected: RegExp(r'url$'),
        actual: '/some/url',
        result: true,
      ),
      _Case(
        expected: RegExp(r'url$'),
        actual: '/some/url/other',
        result: false,
      ),
      _Case(
        expected: RegExp(r'url$'),
        actual: '/some/url?something',
        query: 'other',
        result: false,
      ),
      _Case(
        expected: RegExp(r'url$'),
        actual: '/some/url?something',
        query: 'something',
        result: true,
      ),
      // Function
      _Case(
        expected: (Uri uri) => true,
        actual: '/some/url?something',
        result: true,
      ),
      _Case(
        expected: (Uri uri) => false,
        actual: '/some/url?something',
        result: false,
      ),
      // Matcher
      _Case(
        expected: startsWith('/some'),
        actual: '/some/url',
        result: true,
      ),
      _Case(
        expected: '/some/url',
        actual: '/some/url?a=5',
        query: {'a': anyOf('5', '6')},
        result: true,
      ),
      // Query function
      _Case(
        expected: '/some/url',
        query: (Map<String, String> data) => false,
        actual: '/some/url',
        result: false,
      ),
      _Case(
        expected: '/some/url',
        query: (Map<String, String> data) => true,
        actual: '/some/url',
        result: true,
      ),
      _Case(
        expected: '/some/url',
        query: (Map<String, List<String>> data) => false,
        actual: '/some/url',
        result: false,
      ),
      _Case(
        expected: '/some/url',
        query: (Map<String, List<String>> data) => true,
        actual: '/some/url',
        result: true,
      ),
      _Case(
        expected: startsWith('/some/url?value='),
        actual: '/some/url?value=12312312',
        result: true,
      ),
    ];

    cases.forEach((c) {
      var description = c.expected.toString();

      if (c.query != null) {
        if (c.query is String) {
          description += ' "${c.query}"';
        } else {
          description += ' ${c.query}';
        }
      }

      description += ' -> ${c.actual}';

      test(description, () {
        final matcher = UriMatcher(base, c.expected);

        if (c.query != null) {
          matcher.expected = c.query;
        }

        expect(
          matcher.match(Uri.parse(base + c.actual!)),
          c.result,
        );
      });
    });
  });
}

class _Case {
  final dynamic expected;
  final dynamic query;
  final String? actual;
  final bool? result;

  _Case({this.expected, this.actual, this.query, this.result});
}
