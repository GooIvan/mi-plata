import 'package:flutter_test/flutter_test.dart';

import 'integration_harness.dart';

void main() {
  group('IntegrationHarness.assertLocal', () {
    test('acepta el Supabase local', () {
      IntegrationHarness.assertLocal('http://127.0.0.1:54321');
      IntegrationHarness.assertLocal('http://localhost:54321');
    });

    test('rechaza la nube y cualquier otro servidor', () {
      for (final url in [
        'https://fahkzkbpkovccrbsoggg.supabase.co',
        'https://127.0.0.1.evil.com',
        'http://192.168.1.10:54321',
        '',
      ]) {
        expect(
          () => IntegrationHarness.assertLocal(url),
          throwsStateError,
          reason: url,
        );
      }
    });
  });
}
