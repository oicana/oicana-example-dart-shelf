import 'dart:io';
import 'dart:typed_data';

import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import 'app.dart';

class BlobStore {
  BlobStore(this.directory);

  final String directory;
  final _blobs = <String, Uint8List>{};

  /// Expects a lowercase UUID.
  Future<Uint8List?> get(String id) async {
    if (_blobs[id] case final data?) return data;

    final path = '$directory/$id';
    try {
      return _blobs[id] = await File(path).readAsBytes();
    } on FileSystemException catch (error) {
      log('Failed to read blob $id path=$path error=$error');
      return null;
    }
  }

  Future<String> add(Uint8List data) async {
    final id = const Uuid().v4();
    await Directory(directory).create(recursive: true);
    await File('$directory/$id').writeAsBytes(data);
    _blobs[id] = data;
    return id;
  }
}

class BlobHandlers {
  BlobHandlers(this.blobs);

  final BlobStore blobs;

  void register(Router router) {
    router.post('/blobs', upload);
  }

  Future<Response> upload(Request request) async {
    final Uint8List? data;
    try {
      data = await _formFile(request, 'file');
    } on Exception catch (error) {
      log('Failed to read the uploaded file error=$error');
      return errorResponse(400, 'Failed to read file');
    }
    if (data == null) {
      log('Failed to read the uploaded file error=no file field');
      return errorResponse(400, 'No file field provided');
    }

    final String id;
    try {
      id = await blobs.add(data);
    } on FileSystemException catch (error) {
      log('Failed to store the blob error=$error');
      return errorResponse(500, 'Failed to save file');
    }
    log('Stored blob $id to disk and cache');
    return jsonResponse(200, {'id': id});
  }
}

/// The content of the multipart form field [name], or `null` if the request
/// has no such field.
Future<Uint8List?> _formFile(Request request, String name) async {
  final contentType = request.headers['content-type'];
  if (contentType == null) return null;
  final mediaType = MediaType.parse(contentType);
  final boundary = mediaType.parameters['boundary'];
  if (mediaType.mimeType != 'multipart/form-data' || boundary == null) {
    return null;
  }

  final parts = MimeMultipartTransformer(boundary).bind(request.read());
  await for (final part in parts) {
    final disposition = part.headers['content-disposition'];
    if (disposition != null &&
        RegExp(
          '(^|;)\\s*name="${RegExp.escape(name)}"',
        ).hasMatch(disposition)) {
      final builder = BytesBuilder(copy: false);
      await part.forEach(builder.add);
      return builder.takeBytes();
    }
    await part.drain<void>();
  }
  return null;
}
