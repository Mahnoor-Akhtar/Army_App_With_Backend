import 'dart:typed_data';

Future<String> saveAndDownloadFile({
  required String filename,
  required Uint8List bytes,
  required String mimeType,
}) async {
  throw UnsupportedError('Cannot save file without platform implementation.');
}
