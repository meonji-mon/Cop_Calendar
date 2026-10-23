import 'package:events_app/function/f_url_href.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('valid HTTP and HTTPS links preserve encoded path, query and fragment',
      () async {
    for (final url in [
      'https://example.test/a%20b?x=1#section',
      'http://example.test/path',
    ]) {
      Uri? launched;
      expect(
          await launchURL(url, open: (uri) async {
            launched = uri;
            return true;
          }),
          isTrue);
      expect(launched.toString(), url);
    }
  });

  for (final url in [
    'javascript:alert(1)',
    'data:text/html,example',
    'file:///tmp/example',
    'intent://example/#Intent;scheme=example;end',
    'tel:01000000000',
    'mailto:test@example.test',
    'custom-app://action',
    '//example.test/path',
    '/relative/path',
    'https:',
    'https:///path',
    'https://',
    'https://user:password@example.test',
    'https://example.test\n/path',
    ' https://example.test',
    'https://example.test/%zz',
    'https://[invalid',
    '',
  ]) {
    test('rejects unsafe or malformed link: ${url.replaceAll('\n', r'\n')}',
        () async {
      var launches = 0;
      expect(
          await launchURL(url, open: (_) async {
            launches++;
            return true;
          }),
          isFalse);
      expect(launches, 0);
    });
  }

  test('launcher rejection and exceptions fail quietly', () async {
    expect(await launchURL('https://example.test', open: (_) async => false),
        isFalse);
    expect(
        await launchURL('https://example.test', open: (_) async {
          throw StateError('Mock platform failure');
        }),
        isFalse);
  });
}
