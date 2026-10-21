# Oicana Example using Dart with shelf

Small example Dart web service with [shelf](https://pub.dev/packages/shelf) that uses Oicana for PDF templating.

## Getting Started

1. Install the dependencies: `dart pub get`
2. Start the service: `dart run bin/server.dart`
3. Visit http://127.0.0.1:3008/swagger/ for the Swagger documentation

The first build downloads the native Oicana library for your platform. To deploy the service, build it with `dart build cli -t bin/server.dart`, which puts the native library next to the executable, and run `build/cli/<platform>/bundle/bin/server` from the root of this repository.

## Licensing

The code of this example project is licensed under the [MIT license](LICENSE).

But please be aware, that the Oicana dependency [is licensed under PolyForm Noncommercial License 1.0.0][oicana-license] and, after 30 days, requires a commercial license for use cases that are not covered by the PolyForm license. Visit [the Oicana website][oicana-website] for pricing options.


[oicana-license]: https://github.com/oicana/oicana?tab=readme-ov-file#licensing
[oicana-website]: https://oicana.com
