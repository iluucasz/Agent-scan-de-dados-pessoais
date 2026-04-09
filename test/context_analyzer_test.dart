import 'package:flutter_test/flutter_test.dart';
import 'package:seusdados/services/context_analyzer.dart';

void main() {
  // ─── analyze() ────────────────────────────────────────────────────

  group('ContextAnalyzer.analyze', () {
    test('returns positive signal when CPF label present', () {
      const line = 'CPF do titular: 529.982.247-25';
      final signal = ContextAnalyzer.analyze(
        patternId: 'cpf',
        line: line,
        matchStart: 16,
        matchEnd: 30,
      );

      expect(signal.score, greaterThan(0));
      expect(signal.matchedKeyword, isNotNull);
    });

    test('returns negative signal for CPF in protocol context', () {
      const line = 'Protocolo de atendimento: 52998224725';
      final signal = ContextAnalyzer.analyze(
        patternId: 'cpf',
        line: line,
        matchStart: 26,
        matchEnd: 37,
      );

      expect(signal.score, lessThan(0));
    });

    test('returns neutral for unknown pattern id', () {
      const line = 'algum dado qualquer: 12345';
      final signal = ContextAnalyzer.analyze(
        patternId: 'padrao_desconhecido',
        line: line,
        matchStart: 21,
        matchEnd: 26,
      );

      expect(signal.score, equals(0.0));
      expect(signal.matchedKeyword, isNull);
    });

    test('returns positive signal when CNPJ label present', () {
      const line = 'CNPJ da empresa: 04.252.011/0001-10';
      final signal = ContextAnalyzer.analyze(
        patternId: 'cnpj',
        line: line,
        matchStart: 17,
        matchEnd: 35,
      );

      expect(signal.score, greaterThan(0));
    });

    test('returns positive signal for RG with identidade label', () {
      const line = 'Identidade (RG): 12.345.678-9';
      final signal = ContextAnalyzer.analyze(
        patternId: 'rg',
        line: line,
        matchStart: 17,
        matchEnd: 29,
      );

      expect(signal.score, greaterThan(0));
    });

    test('returns positive signal for nome_completo with label', () {
      const line = 'Nome do cliente: João Silva';
      final signal = ContextAnalyzer.analyze(
        patternId: 'nome_completo',
        line: line,
        matchStart: 17,
        matchEnd: 27,
      );

      expect(signal.score, greaterThan(0));
    });

    test('returns negative signal for nome_completo in code context', () {
      const line = 'import Something From package:example';
      final signal = ContextAnalyzer.analyze(
        patternId: 'nome_completo',
        line: line,
        matchStart: 7,
        matchEnd: 16,
      );

      expect(signal.score, lessThan(0));
    });

    test('returns positive signal for CEP with label', () {
      const line = 'CEP: 01310-100';
      final signal = ContextAnalyzer.analyze(
        patternId: 'cep',
        line: line,
        matchStart: 5,
        matchEnd: 14,
      );

      expect(signal.score, greaterThan(0));
    });

    test('returns positive for data_nascimento with label', () {
      const line = 'Data de nascimento: 15/03/1990';
      final signal = ContextAnalyzer.analyze(
        patternId: 'data_nascimento',
        line: line,
        matchStart: 20,
        matchEnd: 30,
      );

      expect(signal.score, greaterThan(0));
    });

    test('returns negative for date in emission context', () {
      const line = 'Data de emissão: 15/03/2024';
      final signal = ContextAnalyzer.analyze(
        patternId: 'data_nascimento',
        line: line,
        matchStart: 17,
        matchEnd: 27,
      );

      expect(signal.score, lessThan(0));
    });

    test('context window handles match at start of line', () {
      const line = '529.982.247-25 é o CPF';
      final signal = ContextAnalyzer.analyze(
        patternId: 'cpf',
        line: line,
        matchStart: 0,
        matchEnd: 14,
      );

      expect(signal.score, greaterThan(0));
    });

    test('context window handles match at end of line', () {
      const line = 'CPF 529.982.247-25';
      final signal = ContextAnalyzer.analyze(
        patternId: 'cpf',
        line: line,
        matchStart: 4,
        matchEnd: 18,
      );

      expect(signal.score, greaterThan(0));
    });

    test('positive + negative keywords produce net score', () {
      // Both "cpf" (positive) and "protocolo" (negative) present.
      const line = 'CPF protocolo: 52998224725';
      final signal = ContextAnalyzer.analyze(
        patternId: 'cpf',
        line: line,
        matchStart: 15,
        matchEnd: 26,
      );

      // Net: 0.35 - 0.50 = -0.15
      expect(signal.score, lessThan(0));
    });
  });

  // ─── isAmbiguousPattern() ─────────────────────────────────────────

  group('ContextAnalyzer.isAmbiguousPattern', () {
    test('returns true for known ambiguous patterns', () {
      expect(ContextAnalyzer.isAmbiguousPattern('rg'), isTrue);
      expect(ContextAnalyzer.isAmbiguousPattern('cnh'), isTrue);
      expect(ContextAnalyzer.isAmbiguousPattern('cep'), isTrue);
      expect(ContextAnalyzer.isAmbiguousPattern('data_nascimento'), isTrue);
      expect(ContextAnalyzer.isAmbiguousPattern('nome_completo'), isTrue);
      expect(ContextAnalyzer.isAmbiguousPattern('endereco_ip'), isTrue);
    });

    test('returns false for non-ambiguous patterns', () {
      expect(ContextAnalyzer.isAmbiguousPattern('cpf'), isFalse);
      expect(ContextAnalyzer.isAmbiguousPattern('cnpj'), isFalse);
      expect(ContextAnalyzer.isAmbiguousPattern('email'), isFalse);
      expect(ContextAnalyzer.isAmbiguousPattern('cartao_credito'), isFalse);
    });
  });
}
