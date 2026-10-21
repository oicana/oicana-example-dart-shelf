import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:oicana_example_dart_shelf/oicana_example.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

late Handler handler;

Future<Response> serve(
  String method,
  String path, {
  String? contentType,
  Object? body,
}) async => handler(
  Request(
    method,
    Uri.parse('http://localhost$path'),
    headers: {'content-type': ?contentType},
    body: body,
  ),
);

void expectResponse(Response response, int status, String contentType) {
  expect(response.statusCode, status);
  expect(response.headers['content-type'], startsWith(contentType));
}

void main() {
  late TemplateRegistry templates;
  late Directory blobDir;

  setUpAll(() async {
    blobDir = await Directory.systemTemp.createTemp('blobs');
    await for (final blob in Directory('blobs').list()) {
      await (blob as File).copy(
        '${blobDir.path}/${blob.uri.pathSegments.last}',
      );
    }
    templates = await TemplateRegistry.warmUp('templates');
    handler = buildHandler(templates, BlobStore(blobDir.path));
  });

  tearDownAll(() async {
    templates.close();
    await blobDir.delete(recursive: true);
  });

  test('root links the swagger documentation', () async {
    final response = await serve('GET', '/');
    expectResponse(response, 200, 'text/html');
    expect(await response.readAsString(), contains('/swagger/'));
  });

  test('serves the swagger documentation', () async {
    expectResponse(await serve('GET', '/swagger/'), 200, 'text/html');
    expectResponse(
      await serve('GET', '/swagger/doc.json'),
      200,
      'application/json',
    );
  });

  test('lists templates', () async {
    final response = await serve('GET', '/templates');
    expectResponse(response, 200, 'application/json');
    expect(
      jsonDecode(await response.readAsString()),
      hasLength(templateVersions.length),
    );
  });

  test('downloads templates', () async {
    expectResponse(
      await serve('GET', '/templates/table'),
      200,
      'application/zip',
    );
    expectResponse(
      await serve('GET', '/templates/unknown'),
      404,
      'application/json',
    );
  });

  test('compiles the swagger example', () async {
    final doc = jsonDecode(
      await (await serve('GET', '/swagger/doc.json')).readAsString(),
    );
    final payload = jsonEncode(
      doc['definitions']['CompilationPayload']['example'],
    );

    final response = await serve(
      'POST',
      '/templates/invoice/compile',
      contentType: 'application/json',
      body: payload,
    );
    expectResponse(response, 200, 'application/pdf');
    expect(ascii.decode((await response.read().first).sublist(0, 4)), '%PDF');
    expectResponse(
      await serve(
        'POST',
        '/templates/invoice/preview',
        contentType: 'application/json',
        body: payload,
      ),
      200,
      'image/png',
    );
  });

  group('compile errors', () {
    final cases = {
      'unknown template': (
        '/templates/unknown/compile',
        '{"jsonInputs": []}',
        404,
      ),
      'malformed body': ('/templates/table/compile', '{"jsonInputs": ', 400),
      'unknown blob': (
        '/templates/minimal/compile',
        '{"blobInputs": [{"key": "logo", "blobId": "11111111-1111-1111-1111-111111111111"}]}',
        400,
      ),
      'undeclared input': (
        '/templates/table/compile',
        '{"jsonInputs": [{"key": "unknown", "value": {}}]}',
        400,
      ),
    };
    for (final MapEntry(key: name, value: (path, payload, status))
        in cases.entries) {
      test(name, () async {
        final response = await serve(
          'POST',
          path,
          contentType: 'application/json',
          body: payload,
        );
        expectResponse(response, status, 'application/json');
      });
    }
  });

  test('creates certificates', () async {
    expectResponse(
      await serve(
        'POST',
        '/certificates',
        contentType: 'application/json',
        body: '{"name": "Test User"}',
      ),
      200,
      'application/pdf',
    );
  });

  test('uploads blobs', () async {
    const boundary = 'boundary';
    final body = [
      '--$boundary',
      'Content-Disposition: form-data; name="file"; filename="test.txt"',
      'Content-Type: text/plain',
      '',
      'test content',
      '--$boundary--',
      '',
    ].join('\r\n');

    final response = await serve(
      'POST',
      '/blobs',
      contentType: 'multipart/form-data; boundary=$boundary',
      // Like the body of a request coming from shelf_io.
      body: Stream<Uint8List>.value(utf8.encode(body)),
    );
    expectResponse(response, 200, 'application/json');
    final id = jsonDecode(await response.readAsString())['id'];
    expect(await File('${blobDir.path}/$id').readAsString(), 'test content');
  });

  // Runs last, since it removes a template from the shared handler.
  test('resets templates', () async {
    expect((await serve('POST', '/templates/fonts/reset')).statusCode, 204);
    expect((await serve('POST', '/templates/fonts/reset')).statusCode, 404);
    expectResponse(
      await serve(
        'POST',
        '/templates/fonts/compile',
        contentType: 'application/json',
        body: '{}',
      ),
      404,
      'application/json',
    );
  });
}
