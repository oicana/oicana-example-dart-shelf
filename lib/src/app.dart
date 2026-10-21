import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'blobs.dart';
import 'certificates.dart';
import 'openapi.dart';
import 'templates.dart';

Handler buildHandler(TemplateRegistry templates, BlobStore blobs) {
  final router = Router()
    ..get(
      '/',
      (Request request) => Response.ok(
        'Visit the swagger documentation at <a href="/swagger/">/swagger/</a>',
        headers: {'Content-Type': 'text/html; charset=utf-8'},
      ),
    )
    ..get('/swagger/doc.json', (Request request) => jsonResponse(200, openApi))
    ..get('/swagger/', swaggerUi);
  TemplateHandlers(templates, blobs).register(router);
  CertificateHandlers(templates).register(router);
  BlobHandlers(blobs).register(router);

  return const Pipeline().addMiddleware(logRequests()).addHandler(router.call);
}

Response swaggerUi(Request request) => Response.ok(
  '''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Oicana example</title>
  <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5.29.0/swagger-ui.css">
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="https://unpkg.com/swagger-ui-dist@5.29.0/swagger-ui-bundle.js"></script>
  <script>SwaggerUIBundle({url: "/swagger/doc.json", dom_id: "#swagger-ui"});</script>
</body>
</html>''',
  headers: {'Content-Type': 'text/html; charset=utf-8'},
);

Middleware logRequests() =>
    (Handler inner) => (Request request) async {
      final stopwatch = Stopwatch()..start();
      final response = await inner(request);
      log(
        'Request handled method=${request.method} path=/${request.url.path} '
        'status=${response.statusCode} duration=${stopwatch.elapsed}',
      );
      return response;
    };

void log(String message) =>
    print('${DateTime.now().toIso8601String()} $message');

Response jsonResponse(int status, Object? body) => Response(
  status,
  body: jsonEncode(body),
  headers: {'Content-Type': 'application/json'},
);

Response errorResponse(int status, String message) =>
    jsonResponse(status, {'message': message});
