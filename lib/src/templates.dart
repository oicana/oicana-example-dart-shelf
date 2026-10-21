import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:oicana/oicana.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import 'app.dart';
import 'blobs.dart';

const templateVersions = [
  (id: 'accessibility', version: '0.1.0'),
  (id: 'certificate', version: '0.1.0'),
  (id: 'dependency', version: '0.1.0'),
  (id: 'fonts', version: '0.1.0'),
  (id: 'invoice', version: '0.1.0'),
  (id: 'invoice_zugferd', version: '0.1.0'),
  (id: 'minimal', version: '0.1.0'),
  (id: 'table', version: '0.1.0'),
  (id: 'multi_input', version: '0.1.0'),
];

String templatePath(String directory, String id, String version) =>
    '$directory/$id-$version.zip';

class TemplateRegistry {
  TemplateRegistry._(this._templates);

  final Map<String, Template> _templates;

  static Future<TemplateRegistry> warmUp(String directory) async {
    final templates = <String, Template>{};
    for (final (:id, :version) in templateVersions) {
      final path = templatePath(directory, id, version);
      final Uint8List files;
      try {
        files = await File(path).readAsBytes();
      } on FileSystemException catch (error) {
        log('Template file not found during warm-up path=$path error=$error');
        continue;
      }
      try {
        templates[id] = await Template.load(files);
      } on OicanaException catch (error) {
        log(
          'Template failed to compile during warm-up path=$path error=$error',
        );
        continue;
      }
      log('Warmed-up $id v$version');
    }
    return TemplateRegistry._(templates);
  }

  Template? operator [](String id) => _templates[id];

  // Exports that are still running finish normally after the template is disposed.
  bool remove(String id) {
    final template = _templates.remove(id);
    template?.dispose();
    return template != null;
  }

  void close() {
    for (final template in _templates.values) {
      template.dispose();
    }
    _templates.clear();
  }
}

class TemplateHandlers {
  TemplateHandlers(this.templates, this.blobs);

  final TemplateRegistry templates;
  final BlobStore blobs;

  void register(Router router) {
    router
      ..get('/templates', list)
      ..get('/templates/<templateId>', download)
      ..post('/templates/<templateId>/compile', compile)
      ..post('/templates/<templateId>/preview', preview)
      ..post('/templates/<templateId>/reset', reset);
  }

  Response list(Request request) =>
      jsonResponse(200, [for (final t in templateVersions) t.id]);

  Future<Response> download(Request request, String templateId) async {
    for (final (:id, :version) in templateVersions) {
      if (id == templateId) {
        final file = File(templatePath('templates', id, version));
        return Response.ok(
          file.openRead(),
          headers: {
            'Content-Type': 'application/zip',
            'Content-Disposition': 'attachment; filename="$id.zip"',
            'Content-Length': '${await file.length()}',
          },
        );
      }
    }
    return errorResponse(404, 'Template not found');
  }

  Future<Response> compile(Request request, String templateId) =>
      _export(request, templateId, pdfDocument);

  Future<Response> preview(Request request, String templateId) =>
      _export(request, templateId, pngPreview);

  Future<Response> _export(Request request, String id, Output output) async {
    if (templates[id] == null) {
      return errorResponse(404, "Template '$id' not found!");
    }

    final CompilationPayload payload;
    try {
      payload = CompilationPayload.fromJson(
        jsonDecode(await request.readAsString()),
      );
    } on FormatException catch (error) {
      return errorResponse(400, 'Invalid request body: ${error.message}');
    }

    final blobInputs = <String, BlobInput>{};
    for (final (:key, :blobId) in payload.blobInputs) {
      final data = await blobs.get(blobId);
      if (data == null) {
        return errorResponse(
          400,
          'Blob with id $blobId not found. '
          'Please use an ID of a blob that was previously uploaded.',
        );
      }
      blobInputs[key] = BlobInput(data);
    }

    // Look the template up again, it might have been reset while reading the request.
    final template = templates[id];
    if (template == null) {
      return errorResponse(404, "Template '$id' not found!");
    }
    final Uint8List document;
    try {
      document = await template.export(
        output.format,
        jsonInputs: payload.jsonInputs,
        blobInputs: blobInputs,
        mode: output.mode,
      );
    } on Exception catch (error) {
      return oicanaErrorResponse(id, error);
    }

    return Response.ok(
      document,
      headers: {
        'Content-Type': output.contentType,
        'Content-Disposition':
            '${output.disposition}; filename="$id.${output.extension}"',
      },
    );
  }

  Response reset(Request request, String templateId) {
    if (!templates.remove(templateId)) {
      log("Template '$templateId' not found in cache");
      return Response.notFound(null);
    }
    log("Template '$templateId' removed from cache");
    return Response(204);
  }
}

class CompilationPayload {
  CompilationPayload(this.jsonInputs, this.blobInputs);

  /// Throws a [FormatException] for payloads that do not match the schema.
  factory CompilationPayload.fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const FormatException('expected a JSON object');
    }
    final jsonInputs = <String, Object?>{
      for (final input in _list(json, 'jsonInputs'))
        _string(input, 'key'): input['value'],
    };
    final blobInputs = [
      for (final input in _list(json, 'blobInputs'))
        (key: _string(input, 'key'), blobId: _uuid(input, 'blobId')),
    ];
    return CompilationPayload(jsonInputs, blobInputs);
  }

  final Map<String, Object?> jsonInputs;
  final List<({String key, String blobId})> blobInputs;

  static List<Map<String, Object?>> _list(
    Map<String, Object?> json,
    String key,
  ) => switch (json[key]) {
    null => const [],
    List<Object?> list
        when list.every((item) => item is Map<String, Object?>) =>
      list.cast(),
    _ => throw FormatException("'$key' must be a list of objects"),
  };

  static String _string(Map<String, Object?> json, String key) =>
      switch (json[key]) {
        String value => value,
        _ => throw FormatException("'$key' must be a string"),
      };

  static String _uuid(Map<String, Object?> json, String key) {
    final value = _string(json, key);
    if (!Uuid.isValidUUID(fromString: value)) {
      throw FormatException("'$key' must be a UUID, got '$value'");
    }
    return value.toLowerCase();
  }
}

class Output {
  const Output(
    this.format,
    this.mode,
    this.contentType,
    this.disposition,
    this.extension,
  );

  final ExportFormat format;
  final CompilationMode mode;
  final String contentType;
  final String disposition;
  final String extension;
}

const pdfDocument = Output(
  ExportFormat.pdf,
  CompilationMode.production,
  'application/pdf',
  'attachment',
  'pdf',
);
const pngPreview = Output(
  ExportFormat.png(pixelsPerPt: 1),
  CompilationMode.development,
  'image/png',
  'inline',
  'png',
);

Response oicanaErrorResponse(String id, Exception error) {
  switch (error) {
    case InvalidInputException():
      log("Template '$id' received invalid input error=$error");
      return errorResponse(
        400,
        "Template '$id' received invalid input: $error",
      );
    case CompilationException():
      log("Template '$id' failed to compile with given inputs error=$error");
      return errorResponse(
        400,
        "Template '$id' failed to compile with given inputs: $error",
      );
    case NotFoundException():
      // The template was reset while this request was waiting for it.
      return errorResponse(404, "Template '$id' not found!");
    default:
      log("Template '$id' failed to export error=$error");
      return errorResponse(500, "Template '$id' failed to export!\n$error");
  }
}
