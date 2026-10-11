import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<void> downloadMedia(
  Uint8List bytes,
  String name,
  String mime,
  String fileId,
) async {
  final url = web.URL.createObjectURL(
    web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime)),
  );
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  // Allow the browser to start reading before revoking; bounded lifetime.
  Future<void>.delayed(
    const Duration(seconds: 5),
    () => web.URL.revokeObjectURL(url),
  );
}
