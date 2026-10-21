import 'dart:io';

import 'package:async/async.dart';
import 'package:oicana/oicana.dart';
import 'package:oicana_example_dart_shelf/oicana_example.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

const host = '127.0.0.1';
const port = 3008;

Future<void> main() async {
  configureDiagnosticColor(DiagnosticColor.none);

  final templates = await TemplateRegistry.warmUp('templates');
  final server = await shelf_io.serve(
    buildHandler(templates, BlobStore('blobs')),
    host,
    port,
  );
  log('API docs at http://$host:$port/swagger/');

  await StreamGroup.merge([
    ProcessSignal.sigint.watch(),
    if (!Platform.isWindows) ProcessSignal.sigterm.watch(),
  ]).first;

  await server.close();
  templates.close();
  log('Server shut down');
}
