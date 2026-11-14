import 'dart:js_interop';

@JS('mintadealInstallKind')
external JSString? _installKind();

@JS('mintadealInstallPrompt')
external JSPromise<JSBoolean> _promptInstall();

/// 'installed', 'prompt' (the browser can install it), 'ios' (added from the Share menu) or 'none'. See web/index.html.
String installKind() {
  try {
    return _installKind()?.toDart ?? 'none';
  } on Object {
    return 'none';
  }
}

/// Shows the browser's own install dialog; true when the person accepted.
Future<bool> promptInstall() async {
  try {
    return (await _promptInstall().toDart).toDart;
  } on Object {
    return false;
  }
}
