import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<String> saveAndDownloadFile({
  required String filename,
  required Uint8List bytes,
  required String mimeType,
}) async {
  Directory? directory;

  try {
    if (Platform.isAndroid) {
      // Use the public Downloads folder on Android
      // This path works on Android 9 and above without extra plugins
      const downloadPath = '/storage/emulated/0/Download';
      final dir = Directory(downloadPath);
      if (await dir.exists()) {
        directory = dir;
      } else {
        // Fallback: try getDownloadsDirectory, then external storage
        directory = await getDownloadsDirectory();
        directory ??= await getExternalStorageDirectory();
        directory ??= await getApplicationDocumentsDirectory();
      }
    } else if (Platform.isIOS) {
      // iOS: save to app documents directory
      directory = await getApplicationDocumentsDirectory();
    } else {
      // Windows / Linux / macOS: save to system Downloads folder
      directory = await getDownloadsDirectory();
      directory ??= await getApplicationDocumentsDirectory();
    }
  } catch (e) {
    directory = await getApplicationDocumentsDirectory();
  }

  directory ??= await getApplicationDocumentsDirectory();

  final file = File('${directory.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
