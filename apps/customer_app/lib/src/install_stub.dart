/// Outside the browser the app is already installed: nothing to offer.
String installKind() => 'none';

Future<bool> promptInstall() async => false;
