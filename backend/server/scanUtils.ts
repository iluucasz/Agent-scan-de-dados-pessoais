/**
 * Data scanning utilities for detecting patterns in different data sources
 */

import { DataScanConfig } from '../schemas/scan-data-module.schema';

// Constants for pattern matching (VERSÃO CORRIGIDA - SEM FALSOS POSITIVOS)
const PATTERNS: Record<string, RegExp> = {
  // Personal identifiers - PADRÕES RESTRITIVOS
  CPF: /\b\d{3}\.\d{3}\.\d{3}-\d{2}\b|\b\d{11}\b/, // Brazilian CPF
  
  // RG - APENAS com contexto explícito de documento (pattern mais restritivo)
  RG: /\b\d{1,2}\.\d{3}\.\d{3}[-.]?[0-9X]\b/,
  
  CNPJ: /\b\d{2}\.\d{3}\.\d{3}\/\d{4}-\d{2}\b|\b\d{14}\b/, // Brazilian CNPJ
  PASSPORT: /\b[A-Z]{2}[0-9]{6,7}\b/, // Passport numbers
  
  // Contact information
  EMAIL: /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/,
  PHONE_BR: /\b\(?\d{2}\)?\s*\d{4,5}-\d{4}\b/, // Telefone BR (exige hífen)
  PHONE_INTL: /\b\+\d{1,3}\s?\(\d{1,4}\)\s?\d{1,4}[-\s]?\d{1,9}\b/, // International format
  
  // Financial information - APENAS contas com hífen (mais restritivo)
  CREDIT_CARD: /\b(?:\d{4}[-\s]?){3}\d{4}\b|\b\d{16}\b/,
  BANK_ACCOUNT: /\b\d{4,6}-\d{1,4}\b/, // Apenas contas com hífen
  
  // Addresses and location
  CEP: /\b\d{5}-\d{3}\b|\b\d{8}\b/, // Brazilian postal code
  COORDINATES: /\b-?\d{1,2}\.\d{3,8},\s*-?\d{1,3}\.\d{3,8}\b/, // Geo coordinates
  
  // Health information
  HEALTH_CARD: /\b\d{15}\b/, // Brazilian SUS card
  MEDICAL_RECORD: /\b(PRONTUÁRIO|PRONTUARIO|PRONT|P\.MED)\s*[:#]?\s*\d{4,12}\b/i,
  
  // Other personal identifiers
  DATE_OF_BIRTH: /\b\d{2}\/\d{2}\/\d{4}\b/,
  NAMES: /\b[A-Z][a-z]+\s+(?:[A-Z][a-z]+\s+){1,5}[A-Z][a-z]+\b/, // Names with 2+ words
  // Phase 1 additional Brazilian ids (context-anchored where possible)
  TITULO_ELEITOR: /(?:(?:t[ií]tulo)\s*(?:de)?\s*(?:eleitor)\s*[:#-]?\s*)?\b\d{12}\b/i,
  PIS_PASEP: /\b(?:PIS|PASEP|NIS)\s*[:#-]?\s*\d{11}\b/i,
  CNH: /(?:\bCNH\b|habilita[cç][aã]o|carteira\s+de\s+motorista)\s*[:#-]?\s*\b\d{11}\b/i,
  CTPS: /\b(?:CTPS|carteira\s+de\s+trabalho)\b[\s:,-]*[0-9]{5,12}\b/i,
  RESERVISTA: /\b(?:certificado\s+de\s+reservista|reservista)\b[\s:,-]*[0-9]{5,12}\b/i,
  // Basic personal details (context labels)
  SEXO: /\b(?:sexo|g[eê]nero)\s*[:\-]\s*(?:masculino|feminino|m|f)\b/i,
  NACIONALIDADE: /\b(?:nacionalidade)\s*[:\-]\s*[A-Za-zÀ-ÿ ]{3,}\b/i,
  NATURALIDADE: /\b(?:naturalidade)\s*[:\-]\s*[A-Za-zÀ-ÿ ]{3,}\b/i,
  ESTADO_CIVIL: /\b(?:estado\s*civil)\s*[:\-]\s*(?:solteir[oa]|casad[oa]|vi[uú]v[oa]|separad[oa]|divorciad[oa])\b/i,
  CERTIDAO_NASCIMENTO: /\bcertid[aã]o\s+de\s+nascimento\b[\s:,-]*[\w\-\/]{5,}/i,
  PARENTESCO: /\b(?:pai|m[aã]e|filh[oa]|c[oô]njuge|espos[ao]|irm[aã]o)\b/i,
  FILIACAO: /\bfilia[cç][aã]o\b[\s:,-]*[A-Za-zÀ-ÿ ]{3,}/i,
  // Professional and access
  CARGO: /\b(?:cargo|fun[cç][aã]o)\s*[:\-]\s*[A-Za-zÀ-ÿ\-/ ]{2,}\b/i,
  CONTRATO_TRABALHO: /\bcontrato\s*(?:de)?\s*trabalho\b[\s:,-]*[\w\-/]{3,}/i,
  REGISTRO_CLASSE: /\b(?:OAB|CRM|CRC|CREA|CRF)\s*[:\-]?\s*\d{3,7}\b/i,
  USERNAME: /\b(?:username|usu[aá]rio)\s*[:\-]\s*[A-Za-z0-9._-]{3,}\b/i,
  ENDERECO_IP: /\b(?:ip|endere[cç]o\s*ip)\s*[:\-]?\s*(?:\d{1,3}\.){3}\d{1,3}\b/i,
  LOGIN: /\b(?:login)\s*[:\-]\s*[A-Za-z0-9._-]{3,}\b/i,
  SENHA: /\b(?:senha|password)\s*[:\-]\s*[\S]{4,}\b/i,
  ENDERECO_RESIDENCIA: /\b(?:endere[cç]o|rua|avenida|av\.|logradouro)\b[\s:,-]+[A-Za-zÀ-ÿ0-9 .,'-]{5,}\b/i,
  // Education
  ESCOLARIDADE: /\b(?:escolaridade|instru[cç][aã]o)\s*[:\-]\s*[A-Za-zÀ-ÿ ]{3,}\b/i,
  UNIVERSIDADE: /\b(?:universidade|faculdade|instituto)\b[\s:,-]*[A-Za-zÀ-ÿ ]{3,}\b/i,
  HISTORICO_ESCOLAR: /\b(?:hist[oó]rico\s*escolar|cra|cr)\b/i,
  CERTIFICADO: /\bcertificado\b[\s:,-]*[A-Za-zÀ-ÿ0-9\-/ ]{3,}\b/i,
  REDES_SOCIAIS: /\b(?:facebook|instagram|linkedin|twitter|tiktok|youtube|whatsapp)\b/i,
  // Health (units/context required)
  ALTURA: /\b(?:altura)\s*[:\-]?\s*(?:\d{1,2}(?:,\d{1,2})?\s*m|\d{2,3}\s*cm)\b/i,
  PESO: /\b(?:peso)\s*[:\-]?\s*\d{2,3}\s*kg\b/i,
  TIPO_SANGUINEO: /\b(?:tipo\s*sangu[ií]neo)\s*[:\-]?\s*(?:A|B|AB|O)[+-]\b/i,
  PRESSAO_ARTERIAL: /\b(?:press[aã]o\s*arterial|PA)\s*[:\-]?\s*\d{2,3}\/\d{2,3}\s*mmHg\b/i,
  GLICEMIA: /\b(?:glicemia)\s*[:\-]?\s*\d{1,3}\s*mg\/dL\b/i,
  COLESTEROL: /\b(?:colesterol)\s*[:\-]?\s*\d{2,3}\s*mg\/dL\b/i,
  ALERGIAS: /\b(?:alergias?)\b[\s:,-]*[A-Za-zÀ-ÿ ,]{3,}\b/i,
  DOENCAS_CID: /\b(?:CID-?10)\b[\s:,-]*[A-Z]\d{2}(?:\.\d{1,2})?\b/i,
  MEDICACAO: /\b(?:medica[cç][aã]o|f[aá]rmaco)\b[\s:,-]*[A-Za-zÀ-ÿ0-9() ]+\s*(?:\d+\s*(?:mg|mcg|ml))?\b/i,
  RESULTADO_EXAME: /\b(?:resultado\s*de\s*exame|exame\s*laboratorial)\b/i,
  LAUDO_MEDICO: /\b(?:laudo\s*m[eé]dico)\b/i,
  PLANO_SAUDE: /\b(?:plano\s*de\s*sa[uú]de|benefici[aá]rio)\b/i,
  CARTAO_SUS: /\b(?:cart[aã]o\s*SUS|CNS)\b[\s:,-]*\d{15}\b/i,
  DADOS_GENETICOS: /\b(?:dados|teste)s?\s*gen[eé]ticos\b/i,
  // Biometrics (textual mentions)
  BIOMETRIA_DIGITAL: /\b(?:biometria|impress[aã]o\s*digital)\b/i,
  BIOMETRIA_IRIS: /\b(?:biometria|[ií]ris)\b/i,
  BIOMETRIA_FACE: /\b(?:biometria\s*facial|reconhecimento\s*facial)\b/i,
  // Finance advanced
  SALARIO: /\b(?:sal[aá]rio)\b[\s:,-]*R\$\s*\d{1,3}(?:\.\d{3})*,\d{2}\b/i,
  RENDA_MENSAL: /\b(?:renda\s*mensal|faturamento\s*mensal)\b[\s:,-]*R\$\s*\d{1,3}(?:\.\d{3})*,\d{2}\b/i,
  RENDA_ANUAL: /\b(?:renda\s*anual|faturamento\s*anual)\b[\s:,-]*R\$\s*\d{1,3}(?:\.\d{3})*,\d{2}\b/i,
  SITUACAO_FINANCEIRA: /\b(?:score\s*de\s*cr[eé]dito|endividamento)\b/i,
  BANCO_NOME: /\b(?:banco)\b[\s:,-]*[A-Za-zÀ-ÿ ]{3,}\b/i,
  CODIGO_BANCO: /\b(?:c[oó]digo\s*do\s*banco|COMPE)\b[\s:,-]*\d{3}\b/i,
  AGENCIA_BANCARIA: /\b(?:ag[eê]ncia)\b[\s:,-]*\d{3,6}(?:-\d)?\b/i,
  CONTA_BANCARIA: /\b(?:conta\s*banc[aá]ria|conta)\b[\s:,-]*\d{4,12}(?:-\d{1,2})?\b/i,
  PIX_CHAVE_EMAIL: /\b(?:chave\s*pix|pix)\b[\s:,-]*[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/i,
  PIX_CHAVE_TELEFONE: /\b(?:chave\s*pix|pix)\b[\s:,-]*\+?55?\s*\(?\d{2}\)?\s*\d{4,5}-?\d{4}\b/i,
  PIX_CHAVE_CPF_CNPJ: /\b(?:chave\s*pix|pix)\b[\s:,-]*(?:\d{3}\.\d{3}\.\d{3}-\d{2}|\d{11}|\d{2}\.\d{3}\.\d{3}\/\d{4}-\d{2}|\d{14})\b/i,
  PIX_CHAVE_ALEATORIA: /\b(?:chave\s*pix|pix)\b[\s:,-]*(?:[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}|[0-9a-f]{32})\b/i,
  IBAN: /\b[A-Z]{2}\d{2}[A-Z0-9]{11,30}\b/,
  SWIFT_BIC: /\b[A-Z]{4}[A-Z]{2}[A-Z0-9]{2}(?:[A-Z0-9]{3})?\b/, // BIC mais restrito
  BOLETO_LINHA_DIGITAVEL: /\b\d{5}\.\d{5}\s\d{5}\.\d{6}\s\d{5}\.\d{6}\s\d{1}\s\d{14}\b/,
  RENDIMENTOS: /\b(?:rendimentos|proventos|dividendos)\b[\s:,-]*R\$\s*\d{1,3}(?:\.\d{3})*,\d{2}\b/i,
  CONTA_INVESTIMENTO: /\b(?:conta\s*de\s*investimento|c[oó]digo\s*de\s*cliente)\b/i
};

/**
 * Data analyzer for different types of data
 */
export class DataAnalyzer {
  /**
   * Analyzes data for potential personal information patterns
   * @param data The data to analyze
   * @param patterns Specific patterns to look for (if not specified, all patterns will be used)
   * @param metadata Additional context information (file path, line numbers, etc.)
   * @returns Array of matches with confidence levels and detailed location info
   */
  static analyzeText(
    data: string, 
    patterns?: string[], 
    metadata?: {
      file?: string,
      directory?: string,
      table?: string,
      column?: string,
      sheet?: string,
      endpoint?: string,
      page?: number
    }
  ): Array<{
    pattern: string,
    matches: string[],
    confidence: number,
    category: string,
    subcategory: string,
    matchLocations?: Array<{
      line?: number,
      column?: number,
      context: string,
      value: string
    }>,
    // Include metadata
    file?: string,
    directory?: string,
    table?: string,
    column?: string,
    sheet?: string,
    endpoint?: string,
    page?: number
  }> {
    const results = [];
    
    // Determine which patterns to use
    const patternsToUse = patterns && patterns.length > 0
      ? patterns.filter(p => PATTERNS[p.toUpperCase()])
      : Object.keys(PATTERNS);
    
    for (const pattern of patternsToUse) {
      const patternKey = pattern.toUpperCase();
      if (!PATTERNS[patternKey]) continue;
      
      // Find all matches
      const regex = PATTERNS[patternKey];
  const matches: string[] = [];
      const matchLocations = [];
  const valueSet = new Set<string>();
      let match;

      // Create a global, stateful regex for iteration
      const globalRegex = new RegExp(regex.source, regex.flags.includes('g') ? regex.flags : regex.flags + 'g');
      
      // Find all matches and track their locations
  while ((match = globalRegex.exec(data)) !== null) {
        const matchValue = match[0];
        
        // Validação contextual anti-falsos positivos
        const contextStart = Math.max(0, match.index - 100);
        const contextEnd = Math.min(data.length, match.index + matchValue.length + 100);
        const fullContext = data.substring(contextStart, contextEnd);
        
        let shouldSkip = false;
        
  if (patternKey === 'RG') {
          // Rejeitar se for parte de CNPJ
          if (/cnpj/i.test(fullContext) || /12\.345\.678\/0001-90/.test(fullContext)) {
            shouldSkip = true;
          }
          
          // Rejeitar se for IP
          if (/192\.168|10\.|172\./.test(matchValue) || /management_ip|ip/i.test(fullContext)) {
            shouldSkip = true;
          }
          
          // Rejeitar se for CPF válido matematicamente
          if (this.validateCPF(matchValue)) {
            shouldSkip = true;
          }
          
          // Aceitar apenas se tiver contexto de documento
          if (!shouldSkip && !/rg|registro\s+geral|documento|identidade/i.test(fullContext)) {
            shouldSkip = true;
          }
        }

        if (patternKey === 'SWIFT_BIC') {
          const bic = matchValue.toUpperCase();
          const lenOk = bic.length === 8 || bic.length === 11;
          const cc = bic.slice(4, 6);
          const isoCountry = /^[A-Z]{2}$/.test(cc);
          const hasCtx = /(swift|bic|bank|banco|iban|transfer|wire|swift\s*code)/i.test(fullContext);
          if (!lenOk || !isoCountry || (!hasCtx && !/XXX$/.test(bic))) {
            shouldSkip = true;
          }
        }

        if (patternKey === 'DATE_OF_BIRTH') {
          const m = matchValue.match(/(\d{2})\/(\d{2})\/(\d{4})/);
          if (m) {
            const dd = parseInt(m[1], 10), mm = parseInt(m[2], 10), yyyy = parseInt(m[3], 10);
            const dt = new Date(yyyy, mm - 1, dd);
            const now = new Date();
            const validDate = dt.getFullYear() === yyyy && dt.getMonth() === (mm - 1) && dt.getDate() === dd;
            const age = now.getFullYear() - yyyy - ((now.getMonth() < (mm - 1) || (now.getMonth() === (mm - 1) && now.getDate() < dd)) ? 1 : 0);
            if (!validDate || dt > now || age > 120 || yyyy < 1900) {
              shouldSkip = true;
            }
          }
        }

        if (patternKey === 'NAMES') {
          const endings = ['data','nascida','nascimento','sexo','parentesco','nome','certidao','certidão','certid','livro','folha'];
          const last = matchValue.split(/\s+/).pop() || '';
          const norm = last.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase();
          if (endings.includes(norm)) shouldSkip = true;
        }

        if (patternKey === 'PHONE_BR') {
          // Evita 11 dígitos puros serem considerados telefone
          const digits = matchValue.replace(/\D/g, '');
          if (digits.length === 11 && !/-/.test(matchValue)) {
            shouldSkip = true;
          }
        }
        
        if (patternKey === 'BANK_ACCOUNT') {
          // Rejeitar telefones
          if (/phone|telefone|\+55/i.test(fullContext)) {
            shouldSkip = true;
          }
          
          // Rejeitar datas/anos
          if (/\b20\d{2}\b/.test(matchValue) || /date|data|expiry|certificate/i.test(fullContext)) {
            shouldSkip = true;
          }
          
          // Aceitar apenas se tiver contexto bancário
          if (!shouldSkip && !/banco|conta|agência|account|banking/i.test(fullContext)) {
            shouldSkip = true;
          }
        }
        
        // Se passou na validação, adicionar à lista
        if (!shouldSkip) {
          const key = DataAnalyzer.normalizeValue(patternKey, matchValue);
          if (!valueSet.has(key)) {
            matches.push(matchValue);
            valueSet.add(key);
          }
          
          // Calculate line number if we have newlines
          let lineNumber = undefined;
          let columnNumber = undefined;
          if (data.includes('\n')) {
            const beforeMatch = data.substring(0, match.index);
            const lines = beforeMatch.split('\n');
            lineNumber = lines.length;
            columnNumber = lines[lines.length - 1].length + 1;
          }
          
          // Extract display context
          const displayContextStart = Math.max(0, match.index - 80);
          const displayContextEnd = Math.min(data.length, match.index + matchValue.length + 80);
          let context = data.substring(displayContextStart, displayContextEnd);
          
          // Clean up newlines
          context = context.replace(/\n\s*/g, ' ').replace(/\s{2,}/g, ' ').trim();
          
          // Para arquivos XML, expandir contexto para tags completas
          if (context.includes('<') && context.includes('>')) {
            let expandedStart = displayContextStart;
            let expandedEnd = displayContextEnd;
            
            // Procurar tag de abertura anterior
            while (expandedStart > 0 && !data.substring(expandedStart - 1, expandedStart + 1).includes('<')) {
              expandedStart--;
              if (expandedStart < match.index - 120) break;
            }
            
            // Procurar tag de fechamento posterior
            while (expandedEnd < data.length && !data.substring(expandedEnd - 1, expandedEnd + 1).includes('>')) {
              expandedEnd++;
              if (expandedEnd > match.index + matchValue.length + 120) break;
            }
            
            // Recriar contexto expandido se encontrou tags completas
            if (expandedStart !== displayContextStart || expandedEnd !== displayContextEnd) {
              context = data.substring(expandedStart, expandedEnd);
              context = context.replace(/\n\s*/g, ' ').replace(/\s{2,}/g, ' ').trim();
            }
          }
          
          // Criar highlight do match
          const matchIndex = context.indexOf(matchValue);
          if (matchIndex !== -1) {
            const prefix = context.substring(0, matchIndex);
            const suffix = context.substring(matchIndex + matchValue.length);
            context = `${prefix}**${matchValue}**${suffix}`;
          }
          
          matchLocations.push({
            line: lineNumber,
            column: columnNumber,
            context,
            value: matchValue
          });
        }
      }
      
      if (matches.length > 0) {
        const confidence = this.calculateConfidence(patternKey, matches, data);
        const category = this.getCategoryForPattern(patternKey);
        const subcategory = this.getSubcategoryForPattern(patternKey);
        
        results.push({
          pattern: patternKey.toLowerCase(),
          matches,
          confidence,
          category,
          subcategory,
          matchLocations,
          // Add metadata if available
          ...(metadata?.file && { file: metadata.file }),
          ...(metadata?.directory && { directory: metadata.directory }),
          ...(metadata?.table && { table: metadata.table }),
          ...(metadata?.column && { column: metadata.column }),
          ...(metadata?.sheet && { sheet: metadata.sheet }),
          ...(metadata?.endpoint && { endpoint: metadata.endpoint }),
          ...(metadata?.page !== undefined && { page: metadata.page }),
          // Add any extra context from first match location
          ...(matchLocations?.[0]?.line !== undefined && { line: matchLocations[0].line }),
        });
      }
    }
    
    return results;
  }
  
  /**
   * Get the data category for a given pattern
   */
  static getCategoryForPattern(pattern: string): string {
    const patternCategories: {[key: string]: string} = {
      'CPF': 'personal_data',
      'RG': 'personal_data',
      'CNPJ': 'personal_data',
      'PASSPORT': 'personal_data',
      'EMAIL': 'personal_data',
      'PHONE_BR': 'personal_data',
      'PHONE_INTL': 'personal_data',
      'CREDIT_CARD': 'sensitive_data',
      'BANK_ACCOUNT': 'sensitive_data',
      'CEP': 'personal_data',
      'COORDINATES': 'personal_data',
      'HEALTH_CARD': 'sensitive_data',
      'MEDICAL_RECORD': 'sensitive_data',
      'DATE_OF_BIRTH': 'personal_data',
  'NAMES': 'personal_data',
  // Additional catalog
  'TITULO_ELEITOR': 'personal_data',
  'PIS_PASEP': 'personal_data',
  'CNH': 'personal_data',
  'CTPS': 'personal_data',
  'RESERVISTA': 'personal_data',
  'SEXO': 'personal_data',
  'NACIONALIDADE': 'personal_data',
  'NATURALIDADE': 'personal_data',
  'ESTADO_CIVIL': 'personal_data',
  'CERTIDAO_NASCIMENTO': 'personal_data',
  'PARENTESCO': 'personal_data',
  'FILIACAO': 'personal_data',
  'CARGO': 'personal_data',
  'CONTRATO_TRABALHO': 'personal_data',
  'REGISTRO_CLASSE': 'personal_data',
  'USERNAME': 'sensitive_data',
  'ENDERECO_IP': 'sensitive_data',
  'LOGIN': 'sensitive_data',
  'SENHA': 'sensitive_data',
  'ENDERECO_RESIDENCIA': 'personal_data',
  'ESCOLARIDADE': 'personal_data',
  'UNIVERSIDADE': 'personal_data',
  'HISTORICO_ESCOLAR': 'personal_data',
  'CERTIFICADO': 'personal_data',
  'REDES_SOCIAIS': 'personal_data',
  'ALTURA': 'sensitive_data',
  'PESO': 'sensitive_data',
  'TIPO_SANGUINEO': 'sensitive_data',
  'PRESSAO_ARTERIAL': 'sensitive_data',
  'GLICEMIA': 'sensitive_data',
  'COLESTEROL': 'sensitive_data',
  'ALERGIAS': 'sensitive_data',
  'DOENCAS_CID': 'sensitive_data',
  'MEDICACAO': 'sensitive_data',
  'RESULTADO_EXAME': 'sensitive_data',
  'LAUDO_MEDICO': 'sensitive_data',
  'PLANO_SAUDE': 'sensitive_data',
  'CARTAO_SUS': 'sensitive_data',
  'DADOS_GENETICOS': 'sensitive_data',
  'BIOMETRIA_DIGITAL': 'sensitive_data',
  'BIOMETRIA_IRIS': 'sensitive_data',
  'BIOMETRIA_FACE': 'sensitive_data',
  'SALARIO': 'sensitive_data',
  'RENDA_MENSAL': 'sensitive_data',
  'RENDA_ANUAL': 'sensitive_data',
  'SITUACAO_FINANCEIRA': 'sensitive_data',
  'BANCO_NOME': 'sensitive_data',
  'CODIGO_BANCO': 'sensitive_data',
  'AGENCIA_BANCARIA': 'sensitive_data',
  'CONTA_BANCARIA': 'sensitive_data',
  'PIX_CHAVE_EMAIL': 'sensitive_data',
  'PIX_CHAVE_TELEFONE': 'sensitive_data',
  'PIX_CHAVE_CPF_CNPJ': 'sensitive_data',
  'PIX_CHAVE_ALEATORIA': 'sensitive_data',
  'IBAN': 'sensitive_data',
  'SWIFT_BIC': 'sensitive_data',
  'BOLETO_LINHA_DIGITAVEL': 'sensitive_data',
  'RENDIMENTOS': 'sensitive_data',
  'CONTA_INVESTIMENTO': 'sensitive_data'
    };
    
    return patternCategories[pattern] || 'personal_data';
  }
  
  /**
   * Get the data subcategory for a given pattern
   */
  static getSubcategoryForPattern(pattern: string): string {
    const patternSubcategories: {[key: string]: string} = {
      'CPF': 'identification',
      'RG': 'identification',
      'CNPJ': 'identification',
      'PASSPORT': 'identification',
      'EMAIL': 'identification',
      'PHONE_BR': 'identification',
      'PHONE_INTL': 'identification',
      'CREDIT_CARD': 'financial',
      'BANK_ACCOUNT': 'financial',
      'CEP': 'location',
      'COORDINATES': 'location',
      'HEALTH_CARD': 'health',
      'MEDICAL_RECORD': 'health',
      'DATE_OF_BIRTH': 'identification',
  'NAMES': 'identification',
  // Additional catalog
  'TITULO_ELEITOR': 'identification',
  'PIS_PASEP': 'identification',
  'CNH': 'identification',
  'CTPS': 'identification',
  'RESERVISTA': 'identification',
  'SEXO': 'identification',
  'NACIONALIDADE': 'identification',
  'NATURALIDADE': 'identification',
  'ESTADO_CIVIL': 'identification',
  'CERTIDAO_NASCIMENTO': 'identification',
  'PARENTESCO': 'identification',
  'FILIACAO': 'identification',
  'CARGO': 'identification',
  'CONTRATO_TRABALHO': 'identification',
  'REGISTRO_CLASSE': 'identification',
  'USERNAME': 'identification',
  'ENDERECO_IP': 'identification',
  'LOGIN': 'identification',
  'SENHA': 'identification',
  'ENDERECO_RESIDENCIA': 'location',
  'ESCOLARIDADE': 'identification',
  'UNIVERSIDADE': 'identification',
  'HISTORICO_ESCOLAR': 'identification',
  'CERTIFICADO': 'identification',
  'REDES_SOCIAIS': 'contact',
  'ALTURA': 'health',
  'PESO': 'health',
  'TIPO_SANGUINEO': 'health',
  'PRESSAO_ARTERIAL': 'health',
  'GLICEMIA': 'health',
  'COLESTEROL': 'health',
  'ALERGIAS': 'health',
  'DOENCAS_CID': 'health',
  'MEDICACAO': 'health',
  'RESULTADO_EXAME': 'health',
  'LAUDO_MEDICO': 'health',
  'PLANO_SAUDE': 'health',
  'CARTAO_SUS': 'health',
  'DADOS_GENETICOS': 'health',
  'BIOMETRIA_DIGITAL': 'biometric',
  'BIOMETRIA_IRIS': 'biometric',
  'BIOMETRIA_FACE': 'biometric',
  'SALARIO': 'financial',
  'RENDA_MENSAL': 'financial',
  'RENDA_ANUAL': 'financial',
  'SITUACAO_FINANCEIRA': 'financial',
  'BANCO_NOME': 'financial',
  'CODIGO_BANCO': 'financial',
  'AGENCIA_BANCARIA': 'financial',
  'CONTA_BANCARIA': 'financial',
  'PIX_CHAVE_EMAIL': 'financial',
  'PIX_CHAVE_TELEFONE': 'financial',
  'PIX_CHAVE_CPF_CNPJ': 'financial',
  'PIX_CHAVE_ALEATORIA': 'financial',
  'IBAN': 'financial',
  'SWIFT_BIC': 'financial',
  'BOLETO_LINHA_DIGITAVEL': 'financial',
  'RENDIMENTOS': 'financial',
  'CONTA_INVESTIMENTO': 'financial'
    };
    
    return patternSubcategories[pattern] || 'identification';
  }
  
  /**
   * Calculate confidence level for a match
   */
  private static calculateConfidence(pattern: string, matches: string[], context: string): number {
    // Base confidence - can be adjusted per pattern
    const baseConfidence: Record<string, number> = {
      'CPF': 0.95,
      'CNPJ': 0.95,
      'EMAIL': 0.9,
      'PHONE_BR': 0.85,
      'PHONE_INTL': 0.8,
      'CREDIT_CARD': 0.9,
      'BANK_ACCOUNT': 0.7,
      'NAMES': 0.6, // Names have higher false positive rate
      'DATE_OF_BIRTH': 0.8,
      'CEP': 0.85,
      'HEALTH_CARD': 0.9,
      'MEDICAL_RECORD': 0.85,
      'PASSPORT': 0.9,
      'RG': 0.9,
      'COORDINATES': 0.8
    };
    
    // Get base confidence for the pattern, default to 0.75
    let confidence = baseConfidence[pattern] || 0.75;
    
    // Adjust confidence based on context cues
    const contextFactors = [
      { terms: ['nome', 'name', 'cliente', 'customer', 'pessoa', 'person'], pattern: 'NAMES', adjustment: 0.1 },
      { terms: ['email', 'e-mail', 'correio', 'contato', 'contact'], pattern: 'EMAIL', adjustment: 0.1 },
      { terms: ['cpf', 'documento', 'document', 'identidade', 'identity'], pattern: 'CPF', adjustment: 0.1 },
      { terms: ['cnpj', 'empresa', 'company', 'negocio', 'business'], pattern: 'CNPJ', adjustment: 0.1 },
      { terms: ['telefone', 'phone', 'celular', 'mobile', 'contato', 'contact'], pattern: 'PHONE_BR', adjustment: 0.1 },
      { terms: ['telefone', 'phone', 'celular', 'mobile', 'contato', 'contact'], pattern: 'PHONE_INTL', adjustment: 0.1 },
      { terms: ['cartao', 'card', 'credito', 'credit', 'pagamento', 'payment'], pattern: 'CREDIT_CARD', adjustment: 0.1 },
      { terms: ['conta', 'account', 'banco', 'bank', 'agencia', 'agency'], pattern: 'BANK_ACCOUNT', adjustment: 0.1 },
      { terms: ['data', 'date', 'nascimento', 'birth', 'aniversario', 'birthday'], pattern: 'DATE_OF_BIRTH', adjustment: 0.1 },
      { terms: ['endereco', 'address', 'cep', 'postal', 'codigo'], pattern: 'CEP', adjustment: 0.1 },
      { terms: ['cartao', 'card', 'sus', 'saude', 'health'], pattern: 'HEALTH_CARD', adjustment: 0.1 },
      { terms: ['prontuario', 'prontuário', 'medico', 'medical', 'paciente', 'patient'], pattern: 'MEDICAL_RECORD', adjustment: 0.1 },
      { terms: ['passaporte', 'passport', 'viagem', 'travel', 'documento', 'document'], pattern: 'PASSPORT', adjustment: 0.1 },
      { terms: ['rg', 'identidade', 'identity', 'documento', 'document'], pattern: 'RG', adjustment: 0.1 },
      { terms: ['localizacao', 'location', 'coordenadas', 'coordinates', 'gps', 'mapa', 'map'], pattern: 'COORDINATES', adjustment: 0.1 }
    ];
    
    // Adjust confidence based on context
    for (const factor of contextFactors) {
      if (factor.pattern === pattern) {
        // Check if any terms are in the context
        for (const term of factor.terms) {
          if (context.toLowerCase().includes(term.toLowerCase())) {
            confidence = Math.min(0.99, confidence + factor.adjustment);
            break;
          }
        }
      }
    }
    
    // Validation checks for specific patterns
    switch (pattern) {
      case 'CPF':
        // Validate CPF format more strictly
        for (const match of matches) {
          const digits = match.replace(/\D/g, '');
          if (digits.length !== 11 || /^(\d)\1{10}$/.test(digits)) {
            confidence -= 0.3; // Reduce confidence for invalid formats
          }
        }
        break;
        
      case 'CREDIT_CARD':
        // Check for test numbers or common placeholders
        for (const match of matches) {
          const digits = match.replace(/\D/g, '');
          if (/^4111111111111111$|^5500000000000004$/.test(digits)) {
            confidence -= 0.4; // Likely test numbers
          }
        }
        break;
    }
    
    // Return confidence capped between 0.1 and 0.99
    return Math.max(0.1, Math.min(0.99, confidence));
  }
  
  /**
   * Validates a Brazilian CPF number
   * @param cpf CPF number to validate
   * @returns true if valid, false otherwise
   */
  static validateCPF(cpf: string): boolean {
    // Remove non-digits
    cpf = cpf.replace(/\D/g, '');
    
    // Must be 11 digits
    if (cpf.length !== 11) return false;
    
    // Check for known invalid patterns
    if (/^(\d)\1{10}$/.test(cpf)) return false;
    
    // Validate check digits
    let sum = 0;
    let remainder;
    
    // First check digit
    for (let i = 1; i <= 9; i++) {
      sum += parseInt(cpf.substring(i - 1, i)) * (11 - i);
    }
    
    remainder = (sum * 10) % 11;
    if (remainder === 10 || remainder === 11) remainder = 0;
    if (remainder !== parseInt(cpf.substring(9, 10))) return false;
    
    // Second check digit
    sum = 0;
    for (let i = 1; i <= 10; i++) {
      sum += parseInt(cpf.substring(i - 1, i)) * (12 - i);
    }
    
    remainder = (sum * 10) % 11;
    if (remainder === 10 || remainder === 11) remainder = 0;
    if (remainder !== parseInt(cpf.substring(10, 11))) return false;
    
    return true;
  }
  
  /**
   * Analyzes data from different source types based on the scan configuration
   * @param config Scan configuration
   * @param data Raw data from the source
   * @returns Analysis results with detailed context
   */
  static analyzeData(config: DataScanConfig, data: any): any[] {
    const results: any[] = [];
    
    // Get patterns to detect from config
    let patterns: string[] = [];
    
    switch (config.sourceType) {
      case 'database':
        patterns = (config.scanPattern as any)?.patterns || [];
        break;
      case 'file':
        patterns = (config.scanPattern as any)?.patterns || [];
        break;
      case 'api':
        patterns = (config.scanPattern as any)?.patterns || [];
        break;
      case 'directory':
        patterns = (config.scanPattern as any)?.contentPatterns || [];
        break;
    }
    
    // Extract metadata from config
    const metadata: {
      file?: string,
      directory?: string,
      table?: string,
      column?: string,
      sheet?: string,
      endpoint?: string
    } = {};
    
    if (config.sourceType === 'file' && (config.connectionConfig as any).filePath) {
      // Extract directory and filename from path
      const filePath = (config.connectionConfig as any).filePath;
      const lastSeparator = Math.max(filePath.lastIndexOf('/'), filePath.lastIndexOf('\\'));
      
      if (lastSeparator >= 0) {
        metadata.directory = filePath.substring(0, lastSeparator);
        metadata.file = filePath.substring(lastSeparator + 1);
      } else {
        metadata.file = filePath;
      }
      
      // Add sheet info for Excel files
      if (filePath.endsWith('.xlsx') || filePath.endsWith('.xls')) {
        metadata.sheet = (config.connectionConfig as any).sheet || 'Sheet1';
      }
    } else if (config.sourceType === 'database') {
      metadata.table = (config.connectionConfig as any)?.table;
      metadata.column = (config.connectionConfig as any)?.column;
    } else if (config.sourceType === 'api') {
      metadata.endpoint = (config.connectionConfig as any)?.endpoint;
    } else if (config.sourceType === 'directory') {
      metadata.directory = (config.connectionConfig as any)?.directoryPath;
    }
    
    // Handle different data types
    if (typeof data === 'object') {
      try {
        // For directory scans, data may be an array of file contents
        if (config.sourceType === 'directory' && Array.isArray(data)) {
          data.forEach((fileData, index) => {
            const fileMetadata = { ...metadata };
            // Add file name if available in the file data
            if (fileData.file) {
              fileMetadata.file = fileData.file;
              if (fileData.directory) {
                fileMetadata.directory = fileData.directory;
              }
            }
            
            // Convert file data content to string
            let content = '';
            if (typeof fileData === 'string') {
              content = fileData;
            } else if (fileData.content) {
              content = String(fileData.content);
            } else {
              content = JSON.stringify(fileData);
            }
            
            // Analyze text with file metadata
            const fileResults = this.analyzeText(content, patterns, fileMetadata);
            
            // Format and add results with file context
            fileResults.forEach(result => {
              results.push({
                dataType: result.pattern,
                file: fileMetadata.file,
                directory: fileMetadata.directory,
                sampleValue: result.matches[0],
                matches: result.matches.length,
                matchPositions: result.matchLocations,
                confidence: result.confidence,
                category: result.category,
                subcategory: result.subcategory,
                // Add any extra context from first match location
                ...(result.matchLocations?.[0]?.line !== undefined && { line: result.matchLocations[0].line }),
                ...(result.page && { page: result.page })
              });
            });
          });
          
          return results;
        }
        
        // Standard object conversion
        data = JSON.stringify(data);
      } catch (error) {
        data = String(data);
      }
    }
    
    // Ensure data is a string
    if (typeof data !== 'string') {
      data = String(data);
    }
    
    // Analyze the text data with metadata
    const textResults = this.analyzeText(data, patterns, metadata);
    
    // Format and return results
    textResults.forEach(result => {
      results.push({
        dataType: result.pattern,
        sampleValue: result.matches[0],
        matches: result.matches.length,
        matchPositions: result.matchLocations,
        confidence: result.confidence,
        category: result.category,
        subcategory: result.subcategory,
        // Include metadata
        ...(result.file && { file: result.file }),
        ...(result.directory && { directory: result.directory }),
        ...(result.table && { table: result.table }),
        ...(result.column && { column: result.column }),
        ...(result.sheet && { sheet: result.sheet }),
        ...(result.endpoint && { endpoint: result.endpoint }),
        ...(result.page && { page: result.page }),
        // Add any extra context from first match location
        ...(result.matchLocations?.[0]?.line !== undefined && { line: result.matchLocations[0].line }),
      });
    });
    
    return results;
  }

  // Normaliza valores para fins de desduplicação por tipo de dado
  private static normalizeValue(patternKey: string, value: string): string {
    const v = value.trim();
    switch (patternKey) {
      case 'CPF':
      case 'CNPJ':
      case 'PHONE_BR':
      case 'CREDIT_CARD':
      case 'PIS_PASEP':
      case 'CNH':
      case 'CTPS':
      case 'RESERVISTA':
        return v.replace(/\D/g, '');
      case 'EMAIL':
        return v.toLowerCase();
      case 'SWIFT_BIC':
      case 'IBAN':
      case 'PASSPORT':
        return v.toUpperCase();
      default:
        return v.toLowerCase();
    }
  }
}

