import 'dart:js_interop';
import 'package:web/web.dart' as web;

class DraftBrowserGuard {
  late final JSFunction handler;
  DraftBrowserGuard(bool Function() dirty) {
    handler = ((web.Event event) {
      if (dirty()) {
        final e = event as web.BeforeUnloadEvent;
        e.preventDefault();
        e.returnValue = '';
      }
    }).toJS;
    web.window.addEventListener('beforeunload', handler);
  }
  void dispose() => web.window.removeEventListener('beforeunload', handler);
}
