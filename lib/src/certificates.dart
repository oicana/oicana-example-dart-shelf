import 'dart:convert';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'app.dart';
import 'templates.dart';

class CertificateHandlers {
  CertificateHandlers(this.templates);

  final TemplateRegistry templates;

  void register(Router router) {
    router.post('/certificates', create);
  }

  Future<Response> create(Request request) async {
    final String name;
    try {
      name = switch (jsonDecode(await request.readAsString())) {
        {'name': String name} => name,
        _ => throw const FormatException("expected an object with a 'name'"),
      };
    } on FormatException catch (error) {
      return errorResponse(400, 'Invalid request body: ${error.message}');
    }

    final template = templates['certificate'];
    if (template == null) {
      log('Certificate template not found!');
      return errorResponse(500, 'Certificate template not found!');
    }
    final Uint8List pdf;
    try {
      pdf = await template.exportPdf(
        jsonInputs: {
          'certificate': {'name': name},
        },
      );
    } on Exception catch (error) {
      return oicanaErrorResponse('certificate', error);
    }

    return Response.ok(
      pdf,
      headers: {
        'Content-Type': 'application/pdf',
        'Content-Disposition': 'attachment; filename="certificate.pdf"',
      },
    );
  }
}
