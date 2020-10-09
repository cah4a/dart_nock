# Nock

HTTP requests mocking library for dart and flutter.

Nock can be used to test modules that perform HTTP requests in isolation.

Inspired by [nock](https://github.com/nock/nock)

## Installing

Add dev dependency to your `pubspec.yaml`:

```yaml
dev_dependencies:
  nock: ^1.1.2
```

## Basic usage example:

```dart
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

  test("example", () async {
    final interceptor = nock("http://localhost/api").get("/users")
      ..reply(
        200,
        "result",
      );

    final response = await http.get("http://localhost/api/users");

    expect(interceptor.isDone, true);
    expect(response.statusCode, 200);
    expect(response.body, "result");
  });
}
```

### No mock found

if some request isn't mocked `NetConnectionNotAllowed` exception will be thrown:

```dart
void main() {
  test("example", () async {
    expect(
      http.get("http://localhost/api/users"),
      throwsA(TypeMatcher<NetConnectionNotAllowed>()),
    );
  });
}
```

## API

### Creating requests scope

```dart
final String baseUrl = "https://my-server.com";
final scope = nock(baseUrl);
```

### Methods for creating interceptors

- `scope.get(dynamic url)` -> Interceptor
- `scope.post(dynamic url, dynamic body)` -> Interceptor
- `scope.put(dynamic url, dynamic body)` -> Interceptor
- `scope.delete(dynamic url, dynamic body)` -> Interceptor
- `scope.patch(dynamic url, dynamic body)` -> Interceptor
- `scope.head(dynamic url, dynamic body)` -> Interceptor

### Using default base url

You could specify `baseUrl` for automatic scope usage:

```dart
void main(){
  setUpAll((){
    nock.defaultBase = "http://localhost/api";
    nock.init();
  });

  test("example", () async {
    nock.get("/users"); // create mock for GET http://localhost/api/users
  });
}
```

### Url matching

You could use strings, regexp or any matcher from [package:test](https://pub.dev/packages/test):

```dart
final topicsInterceptor = nock.get("/topics")
  ..reply(200);

final usersInterceptor = nock.get(startsWith("/users"))
  ..reply(200);

final tagsInterceptor = nock.get(RegExp(r"^/tags$"))
  ..reply(200);
```

### Specifying request headers

```dart
final interceptor = nock.get("/users")
  ..headers({
    'Session-Token': '59aff48f-369e-4781-a142-b52666cf141f',
  })
  ..reply(200);
```

### Specifying request query string

Using query string:

```dart
final interceptor = nock.get("/users")
  ..query("ids[]=1&ids[]=2")
  ..reply(200);
```

Using example:

```dart
final interceptor = nock.get("/users")
  ..query({"id": 5})
  ..reply(200);
```

Using matchers:

```dart
final interceptor = nock.get("/users")
  ..query(startsWith("something"))
  ..reply(200);

final interceptor = nock.get("/users")
  ..query({'id': anyOf([1, 2, 3])})
  ..reply(200);
```

Using custom match function:

```dart
final interceptor = nock.get("/users")
  ..query((Map<String, List<String>> params) => true)
  ..reply(200);

// or

final interceptor = nock.get("/users")
  ..query((Map<String, String> params) => true)
  ..reply(200);
```

### Specifying request body

Interceptor will parse HTTP request headers and try parse body.

Supported mime-types:
- `application/x-www-form-urlencoded`
- `application/json`
- `application/text`
- `application/text`

Using example:

```dart
final interceptor = nock.post(
    "/users",
    {
      "name": "John",
      "email": "john_doe@gmail.com",
    },
)
  ..reply(204);
```

Using matchers:

```dart
final interceptor = nock.post(
    "/users",
    {
      id: anyOf([1, 2, 3])
      name: any,
      email: TypedMather<String>(),
    },
)
  ..reply(204);
```

Using custom match function:

```dart
final interceptor = nock.post(
    "/users",
    (body) => body is Map,
)
  ..reply(204);
```

If you send binary data you could use custom raw match function:

```dart
final interceptor = nock.post(
    "/users",
    (List<int> body) => true,
)
  ..reply(204);
```

### Specifying reply

application/json:

```dart
final interceptor = nock.get("/users")
  ..reply(200, [
    {
      "id": 1,
      "name": "John",
      "email": "john_doe@gmail.com",
    },
    {
      "id": 2,
      "name": "Mark",
      "email": "zuckerberg@gmail.com",
    },
  ]);
```

text/plain:
```dart
final interceptor = nock.get("/ping")
  ..reply(200, "pong");
```

Other binary data:
```dart
final interceptor = nock.get("/video")
  ..reply(200, <int>[73, 32, 97, 109, 32, 118, 105, 100, 101, 111]);
```

### Specifying reply headers

Other binary data:
```dart
final interceptor = nock.get("/auth")
  ..reply(204, null, {
    "Session-Token": "59aff48f-369e-4781-a142-b52666cf141f",
  });
```


### Persistent requests

To repeat responses for as long as nock is active, use `.persist()`.

```dart
final users = nock.get("/users")
  ..persist()
  ..reply(
    200,
    "result",
  );
```

Note that while a persisted mock will always intercept the requests, it is considered "done" after the first interception.

Canceling pending mock:

```dart
users.cancel();
```

### Do something after reply

```dart
final users = nock.get("/users")
  ..persist()
  ..reply(
    200,
    "result",
  )
  ..onReply(() => print("I'm done"));
```

### Contributions Welcome!

Feel free to open PR or an issue