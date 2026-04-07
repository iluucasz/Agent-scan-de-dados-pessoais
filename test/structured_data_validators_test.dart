import 'package:flutter_test/flutter_test.dart';
import 'package:seusdados/validators/structured_data_validators.dart';

void main() {
  group('StructuredDataValidators.validateCpf', () {
    test('accepts formatted valid CPF', () {
      final result = StructuredDataValidators.validateCpf('529.982.247-25');

      expect(result.isValid, isTrue);
      expect(result.normalizedValue, '52998224725');
      expect(result.confidenceOverride, 0.98);
    });

    test('rejects CPF with invalid verifier digit', () {
      final result = StructuredDataValidators.validateCpf('529.982.247-24');

      expect(result.isValid, isFalse);
    });

    test('rejects repeated digits CPF', () {
      final result = StructuredDataValidators.validateCpf('111.111.111-11');

      expect(result.isValid, isFalse);
    });
  });

  group('StructuredDataValidators.validateCnpj', () {
    test('accepts formatted valid CNPJ', () {
      final result = StructuredDataValidators.validateCnpj(
        '04.252.011/0001-10',
      );

      expect(result.isValid, isTrue);
      expect(result.normalizedValue, '04252011000110');
      expect(result.confidenceOverride, 0.98);
    });

    test('rejects CNPJ with invalid verifier digit', () {
      final result = StructuredDataValidators.validateCnpj(
        '04.252.011/0001-11',
      );

      expect(result.isValid, isFalse);
    });

    test('rejects repeated digits CNPJ', () {
      final result = StructuredDataValidators.validateCnpj(
        '11.111.111/1111-11',
      );

      expect(result.isValid, isFalse);
    });
  });
}
