import 'dart:typed_data';

import 'pdf_exporter_stub.dart'
    if (dart.library.html) 'pdf_exporter_web.dart'
    if (dart.library.io) 'pdf_exporter_io.dart';

Future<bool> exportarPdf({required Uint8List bytes, required String filename}) {
  return exportarPdfImpl(bytes: bytes, filename: filename);
}
