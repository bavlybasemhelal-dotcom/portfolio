import 'package:flutter_test/flutter_test.dart';
import 'package:yogen_portfolio/data/company_repository.dart';
import 'package:yogen_portfolio/domain/project.dart';

void main() {
  test(
    'Deferred contact details remain empty; valid international contacts normalize',
    () {
      expect(
        CompanyRepository.validContacts({'email': '  ', 'whatsapp': ''}),
        isEmpty,
      );
      expect(
        CompanyRepository.validContacts({
          'email': ' hello@example.com ',
          'whatsapp': '+201000000000',
          'website': 'https://example.com',
        }).length,
        3,
      );
    },
  );
  test('Invalid contacts and impersonated website are rejected', () {
    for (final value in [
      {'email': 'bad'},
      {'whatsapp': '01000000000'},
      {'website': 'https://name@host.example'},
    ]) {
      expect(
        () => CompanyRepository.validContacts(value),
        throwsA(isA<ContentFailure>()),
      );
    }
  });
}
