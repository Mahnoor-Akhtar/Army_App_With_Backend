// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

Future<String> saveAndDownloadFile({
  required String filename,
  required Uint8List bytes,
  required String mimeType,
}) async {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);

  // Must be appended to the DOM for Firefox & Safari compatibility
  // ignore: unsafe_html
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';

  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();

  // Small delay before revoking so the browser can start the download
  await Future.delayed(const Duration(milliseconds: 200));
  // Return the URL before revoking so caller can use it if needed
  final resultUrl = url;
  html.Url.revokeObjectUrl(url);
  return resultUrl;
}
