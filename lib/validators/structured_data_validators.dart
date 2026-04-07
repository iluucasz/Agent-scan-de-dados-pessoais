import '../constants/data_patterns.dart';

class StructuredValidationResult {
  final bool isValid;
  final String normalizedValue;
  final double? confidenceOverride;

  const StructuredValidationResult({
    required this.isValid,
    required this.normalizedValue,
    this.confidenceOverride,
  });
}

abstract final class StructuredDataValidators {
  static StructuredValidationResult? validate(
    StructuredDataValidatorType? validatorType,
    String value,
  ) {
    switch (validatorType) {
      case StructuredDataValidatorType.cpf:
        return validateCpf(value);
      case StructuredDataValidatorType.cnpj:
        return validateCnpj(value);
      case null:
        return null;
    }
  }

  static StructuredValidationResult validateCpf(String value) {
    final normalizedValue = digitsOnly(value);

    if (normalizedValue.length != 11 || isRepeatedDigits(normalizedValue)) {
      return StructuredValidationResult(
        isValid: false,
        normalizedValue: normalizedValue,
      );
    }

    final digits = normalizedValue.split('').map(int.parse).toList();
    final firstVerifierDigit = _calculateVerifierDigit(
      digits.take(9).toList(),
      const [10, 9, 8, 7, 6, 5, 4, 3, 2],
    );
    final secondVerifierDigit = _calculateVerifierDigit(
      [...digits.take(9), firstVerifierDigit],
      const [11, 10, 9, 8, 7, 6, 5, 4, 3, 2],
    );

    final isValid =
        digits[9] == firstVerifierDigit && digits[10] == secondVerifierDigit;

    return StructuredValidationResult(
      isValid: isValid,
      normalizedValue: normalizedValue,
      confidenceOverride: isValid ? 0.98 : null,
    );
  }

  static StructuredValidationResult validateCnpj(String value) {
    final normalizedValue = digitsOnly(value);

    if (normalizedValue.length != 14 || isRepeatedDigits(normalizedValue)) {
      return StructuredValidationResult(
        isValid: false,
        normalizedValue: normalizedValue,
      );
    }

    final digits = normalizedValue.split('').map(int.parse).toList();
    final firstVerifierDigit = _calculateVerifierDigit(
      digits.take(12).toList(),
      const [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2],
    );
    final secondVerifierDigit = _calculateVerifierDigit(
      [...digits.take(12), firstVerifierDigit],
      const [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2],
    );

    final isValid =
        digits[12] == firstVerifierDigit && digits[13] == secondVerifierDigit;

    return StructuredValidationResult(
      isValid: isValid,
      normalizedValue: normalizedValue,
      confidenceOverride: isValid ? 0.98 : null,
    );
  }

  static String digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  static bool isRepeatedDigits(String value) {
    if (value.isEmpty) return false;
    return value.split('').every((digit) => digit == value[0]);
  }

  static int _calculateVerifierDigit(
    List<int> digits,
    List<int> weights,
  ) {
    var sum = 0;

    for (var index = 0; index < digits.length; index++) {
      sum += digits[index] * weights[index];
    }

    final remainder = sum % 11;
    return remainder < 2 ? 0 : 11 - remainder;
  }
}
