import 'dart:convert';
import 'dart:io';

import 'package:nock/src/interceptor.dart';
import 'package:test/test.dart';

void main() {
  group('cases', () {
    final cases = [
      _Case(
        expected: "foobar",
        actual: "otherstring",
        result: false,
      ),
      _Case(
        expected: "普通话",
        actual: "普通话",
        result: true,
      ),
      _Case(
        expected: {'a': 1},
        actual: '{ "a": 1 }',
        result: true,
        contentType: ContentType.json,
      ),
      _Case(
        expected: {'a': 2},
        actual: '{ "a": 1 }',
        result: false,
        contentType: ContentType.json,
      ),
      _Case(
        expected: RegExp(r"\d"),
        actual: '1',
        result: true,
      ),
      _Case(
        expected: RegExp(r"\d"),
        actual: 'a',
        result: false,
      ),
      _Case(
        expected: {"foo": anyOf(1, 2, 3)},
        actual: '{ "foo": 1 }',
        result: true,
        contentType: ContentType.json,
      ),
      _Case(
        expected: {"foo": "5"},
        actual: 'foo=5',
        result: true,
        contentType: ContentType.parse("application/x-www-form-urlencoded"),
      ),
      _Case(
        expected: {"foo": "5"},
        actual: 'foo=3',
        result: false,
        contentType: ContentType.parse("application/x-www-form-urlencoded"),
      ),
      _Case(
        expected: {"foo": anyOf("1", "2", "5")},
        actual: 'foo=5',
        result: true,
        contentType: ContentType.parse("application/x-www-form-urlencoded"),
      ),
      _Case(
        expected: contains("foo"),
        actual: '{"foo": 3, "bar": 4}',
        result: true,
        contentType: ContentType.json,
      ),
      _Case(
        expected: anything,
        actual: '',
        result: true,
      ),
    ];

    cases.forEach((c) {
      test("${c.expected} -> ${c.actual}", () {
        final matcher = BodyMatcher(c.expected);
        expect(matcher.match(c.body, c.contentType), c.result);
      });
    });
  });
}

class _Case {
  final expected;
  final actual;
  final bool result;
  final ContentType contentType;

  _Case({this.expected, this.actual, this.result, this.contentType});

  List<int> get body {
    if (actual is String) {
      return utf8.encode(actual);
    }

    return utf8.encode(json.encode(actual));
  }
}
