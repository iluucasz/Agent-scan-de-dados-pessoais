import bcrypt from 'bcrypt';
import crypto from 'crypto';

/**
 * Gera hash para senha usando bcrypt
 * @param password Senha a ser hasheada
 * @returns String com hash
 */
export async function hashPassword(password: string): Promise<string> {
  const saltRounds = 10;
  return await bcrypt.hash(password, saltRounds);
}

/**
 * Compara uma senha com um hash armazenado usando bcrypt
 * @param supplied Senha fornecida
 * @param stored Hash armazenado
 * @returns Boolean indicando se a senha é válida
 */
export async function comparePasswords(supplied: string, stored: string): Promise<boolean> {
  return await bcrypt.compare(supplied, stored);
}

/**
 * Gera um ID único baseado em timestamp e número aleatório
 * @param prefix Prefixo opcional para o ID
 * @returns String contendo ID único
 */
export function generateUniqueId(prefix: string = ''): string {
  const timestamp = Date.now().toString(36);
  const randomStr = Math.random().toString(36).substring(2, 8);
  return `${prefix}${timestamp}${randomStr}`;
}

/**
 * Gera um hash SHA-256 de uma string 
 * @param input String para gerar hash
 * @returns Hash SHA-256 em formato hexadecimal
 */
export function generateSHA256Hash(input: string): string {
  return crypto.createHash('sha256').update(input).digest('hex');
}

/**
 * Verifica se uma string é um UUID válido
 * @param str String para verificar
 * @returns true se for UUID válido, false caso contrário
 */
export function isValidUUID(str: string): boolean {
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  return uuidRegex.test(str);
}

/**
 * Formata bytes para uma representação legível por humanos
 * @param bytes Número de bytes
 * @param decimals Casas decimais a mostrar
 * @returns String formatada (ex: "1.5 MB")
 */
export function formatBytes(bytes: number, decimals: number = 2): string {
  if (bytes === 0) return '0 Bytes';
  
  const k = 1024;
  const dm = decimals < 0 ? 0 : decimals;
  const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
  
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  
  return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
}

/**
 * Normaliza uma string removendo acentos, espaços extras e convertendo para minúsculas
 * @param str String para normalizar
 * @returns String normalizada
 */
export function normalizeString(str: string): string {
  return str
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .trim()
    .replace(/\s+/g, ' ');
}