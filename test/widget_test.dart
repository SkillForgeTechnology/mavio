import 'package:flutter_test/flutter_test.dart';
import 'package:mavio/models/models.dart';

void main() {
  test('Smoke test - models creation', () {
    final org = MavioOrganization(
      id: 'test-org',
      name: 'Test College',
      code: 'TEST',
      createdAt: '2026-09-08T00:00:00Z',
    );
    expect(org.id, equals('test-org'));
    expect(org.code, equals('TEST'));
  });
}
