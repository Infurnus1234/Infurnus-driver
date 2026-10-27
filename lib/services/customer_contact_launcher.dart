import 'package:url_launcher/url_launcher.dart';

/// Opens a composer/dialer only. No call or SMS permission is required.
Future<bool> launchCustomerContactUri(Uri uri) async {
  if (!const ['tel', 'sms'].contains(uri.scheme) ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.host.isNotEmpty ||
      !RegExp(r'^\+?[1-9]\d{7,14}$').hasMatch(uri.path)) {
    return false;
  }
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
