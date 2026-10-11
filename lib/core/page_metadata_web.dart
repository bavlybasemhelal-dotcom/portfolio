import 'package:web/web.dart' as web;

void setPageMetadata(String title, String description, String language) {
  web.document.title = title;
  web.document.documentElement?.setAttribute('lang', language);
  web.document.documentElement?.setAttribute(
    'dir',
    language == 'ar' ? 'rtl' : 'ltr',
  );
  void meta(String name, String value, {bool property = false}) {
    final attr = property ? 'property' : 'name';
    final element =
        web.document.querySelector('meta[$attr="$name"]') ??
        web.document.createElement('meta');
    element.setAttribute(attr, name);
    element.setAttribute('content', value);
    if (element.parentNode == null) web.document.head?.appendChild(element);
  }

  meta('description', description);
  meta('og:title', title, property: true);
  meta('og:description', description, property: true);
  meta('og:type', 'website', property: true);
  meta('og:locale', language == 'ar' ? 'ar_EG' : 'en_US', property: true);
  meta(
    'og:image',
    Uri.parse(
      web.document.baseURI,
    ).resolve('sharing/yogen-logo.png').toString(),
    property: true,
  );
  meta('twitter:card', 'summary');
  meta('twitter:title', title);
  meta('twitter:description', description);
  const released = bool.fromEnvironment('YOGEN_RELEASE');
  final hash = web.window.location.hash;
  final route = hash.startsWith('#')
      ? Uri.tryParse(hash.substring(1))?.path ?? '/'
      : web.window.location.pathname;
  final privateRoute = route == '/admin' ||
      route.startsWith('/admin/') || route.startsWith('/validation');
  meta('robots', released && !privateRoute ? 'index,follow' : 'noindex,nofollow');
  // Hash project routes still share the initial HTML seen by social crawlers.
}
