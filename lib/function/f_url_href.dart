import 'package:url_launcher/url_launcher.dart';

/// Only ordinary web links may be opened from untrusted notification content.
Uri? parseWebLink(String url) {
  if (url.contains(RegExp(r'[\s\x00-\x1f\x7f]|%(?![0-9a-fA-F]{2})'))) {
    return null;
  }
  final uri = Uri.tryParse(url);
  if (uri == null ||
      (uri.scheme != 'https' && uri.scheme != 'http') ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

Future<bool> launchURL(String url, {Future<bool> Function(Uri)? open}) async {
  final uri = parseWebLink(url);
  if (uri == null) return false;
  try {
    return await (open ??
        (uri) => launchUrl(uri, mode: LaunchMode.externalApplication))(uri);
  } catch (_) {
    // URLs and platform errors may contain private notification information.
    return false;
  }
}
