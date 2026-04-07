import { extname } from 'path';

/**
 * Utilitário para sanitização de nomes de arquivos
 * Resolve problemas de encoding para upload no DigitalOcean Spaces
 */

export interface SanitizedFile {
  originalName: string;
  sanitizedName: string;
  wasModified: boolean;
  extension: string;
}

export class FileSanitizer {
  /**
   * Mapeamento de caracteres com acentos para caracteres sem acentos
   */
  private static readonly ACCENT_MAP: Record<string, string> = {
    'á': 'a', 'à': 'a', 'ã': 'a', 'â': 'a', 'ä': 'a', 'å': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'õ': 'o', 'ô': 'o', 'ö': 'o', 'ø': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
    'Á': 'A', 'À': 'A', 'Ã': 'A', 'Â': 'A', 'Ä': 'A', 'Å': 'A',
    'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E',
    'Í': 'I', 'Ì': 'I', 'Î': 'I', 'Ï': 'I',
    'Ó': 'O', 'Ò': 'O', 'Õ': 'O', 'Ô': 'O', 'Ö': 'O', 'Ø': 'O',
    'Ú': 'U', 'Ù': 'U', 'Û': 'U', 'Ü': 'U',
    'Ç': 'C', 'Ñ': 'N'
  };

  /**
   * Remove acentos de uma string
   */
  private static removeAccents(text: string): string {
    return text.replace(/[áàãâäåéèêëíìîïóòõôöøúùûüçñÁÀÃÂÄÅÉÈÊËÍÌÎÏÓÒÕÔÖØÚÙÛÜÇÑ]/g, 
      (match) => this.ACCENT_MAP[match] || match);
  }

  /**
   * Remove caracteres especiais mantendo apenas letras, números, pontos, hífens e underscores
   */
  private static removeSpecialChars(text: string): string {
    return text.replace(/[^a-zA-Z0-9.\-_]/g, '_');
  }

  /**
   * Remove múltiplos underscores consecutivos
   */
  private static cleanUpUnderscores(text: string): string {
    return text.replace(/_+/g, '_').replace(/^_|_$/g, '');
  }

  /**
   * Sanitiza um nome de arquivo para ser compatível com DigitalOcean Spaces
   */
  static sanitizeFileName(fileName: string): SanitizedFile {
    const originalName = fileName;
    const extension = extname(fileName);
    const nameWithoutExt = fileName.replace(extension, '');

    // Aplica as transformações
    let sanitized = nameWithoutExt;
    sanitized = this.removeAccents(sanitized);
    sanitized = this.removeSpecialChars(sanitized);
    sanitized = this.cleanUpUnderscores(sanitized);

    // Garante que o nome não esteja vazio
    if (!sanitized || sanitized.length === 0) {
      sanitized = 'arquivo_sem_nome';
    }

    // Limita o tamanho do nome (DigitalOcean tem limite de 255 caracteres)
    const maxLength = 200 - extension.length; // Deixa margem para extensão
    if (sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }

    const sanitizedName = sanitized + extension.toLowerCase();
    const wasModified = originalName !== sanitizedName;

    return {
      originalName,
      sanitizedName,
      wasModified,
      extension: extension.toLowerCase()
    };
  }

  /**
   * Sanitiza múltiplos arquivos de uma vez
   */
  static sanitizeMultipleFiles(fileNames: string[]): SanitizedFile[] {
    const results: SanitizedFile[] = [];
    const usedNames = new Set<string>();

    for (const fileName of fileNames) {
      let sanitized = this.sanitizeFileName(fileName);
      
      // Resolve conflitos de nomes duplicados
      if (usedNames.has(sanitized.sanitizedName)) {
        let counter = 1;
        let baseName = sanitized.sanitizedName.replace(sanitized.extension, '');
        
        do {
          sanitized.sanitizedName = `${baseName}_${counter}${sanitized.extension}`;
          counter++;
        } while (usedNames.has(sanitized.sanitizedName));
        
        sanitized.wasModified = true;
      }

      usedNames.add(sanitized.sanitizedName);
      results.push(sanitized);
    }

    return results;
  }

  /**
   * Valida se um nome de arquivo é seguro para upload
   */
  static isFileNameSafe(fileName: string): boolean {
    // Verifica se contém apenas caracteres seguros
    const safePattern = /^[a-zA-Z0-9.\-_]+$/;
    return safePattern.test(fileName) && fileName.length <= 255;
  }

  /**
   * Gera um nome único baseado em timestamp
   */
  static generateUniqueFileName(originalName: string): string {
    const sanitized = this.sanitizeFileName(originalName);
    const timestamp = Date.now();
    const randomSuffix = Math.random().toString(36).substring(2, 8);
    const nameWithoutExt = sanitized.sanitizedName.replace(sanitized.extension, '');
    
    return `${nameWithoutExt}_${timestamp}_${randomSuffix}${sanitized.extension}`;
  }

  /**
   * Extrai informações sobre problemas de encoding em um nome de arquivo
   */
  static analyzeFileName(fileName: string): {
    hasAccents: boolean;
    hasSpecialChars: boolean;
    tooLong: boolean;
    isEmpty: boolean;
    issues: string[];
  } {
    const issues: string[] = [];
    
    const hasAccents = /[áàãâäåéèêëíìîïóòõôöøúùûüçñÁÀÃÂÄÅÉÈÊËÍÌÎÏÓÒÕÔÖØÚÙÛÜÇÑ]/.test(fileName);
    const hasSpecialChars = /[^a-zA-Z0-9.\-_]/.test(fileName);
    const tooLong = fileName.length > 255;
    const isEmpty = !fileName || fileName.trim().length === 0;

    if (hasAccents) issues.push('Contém acentos');
    if (hasSpecialChars && !hasAccents) issues.push('Contém caracteres especiais');
    if (tooLong) issues.push('Nome muito longo');
    if (isEmpty) issues.push('Nome vazio');

    return {
      hasAccents,
      hasSpecialChars,
      tooLong,
      isEmpty,
      issues
    };
  }
}

/**
 * Função helper para uso direto
 */
export const sanitizeFileName = FileSanitizer.sanitizeFileName;
export const sanitizeMultipleFiles = FileSanitizer.sanitizeMultipleFiles;
export const isFileNameSafe = FileSanitizer.isFileNameSafe;
export const generateUniqueFileName = FileSanitizer.generateUniqueFileName;
