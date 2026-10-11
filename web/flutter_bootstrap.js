{{flutter_js}}
{{flutter_build_config}}

// Start directly. This app does not register the deprecated generated worker,
// whose cleanup script reloads open clients during its activation.
_flutter.loader.load();
