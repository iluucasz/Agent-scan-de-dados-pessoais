/**
 * Utilidades para análise e estatísticas de dados pessoais
 * Atualizado para trabalhar com dados validados do cliente
 */

/**
 * Interface para dados pessoais validados
 */
export interface ValidatedPersonalData {
  name: string;
  category: string;
  sensitivityLevel: string;
  dataType: string;
  source: string;
  status: string;
  retentionPolicy?: string;
  protectionMethod?: string;
  storageLocation?: string;
  consentStatus?: string;
  sizeBytes?: number;
}


/**
 * Calcula estatísticas sobre dados pessoais validados
 * @param dataItems Array de itens de dados pessoais validados
 * @returns Objeto com estatísticas agregadas
 */
export function calculateDataStats(dataItems: ValidatedPersonalData[]): any {
  // Inicializa contadores
  const stats: {
    total: number;
    byCategory: Record<string, number>;
    bySensitivity: Record<string, number>;
    byRetentionPolicy: Record<string, number>;
    bySource: Record<string, number>;
    byStatus: Record<string, number>;
    byType: Record<string, number>;
    byProtection: Record<string, number>;
    byLocation: Record<string, number>;
    byConsent: Record<string, number>;
    totalSizeBytes: number;
  } = {
    total: dataItems.length,
    byCategory: {},
    bySensitivity: {},
    byRetentionPolicy: {},
    bySource: {},
    byStatus: {},
    byType: {},
    byProtection: {},
    byLocation: {},
    byConsent: {},
    totalSizeBytes: 0
  };

  // Processa cada item de dados
  for (const item of dataItems) {
    // Incrementa contadores por categoria
    if (item.category) {
      stats.byCategory[item.category] = (stats.byCategory[item.category] || 0) + 1;
    }
    
    // Incrementa contadores por nível de sensibilidade
    if (item.sensitivityLevel) {
      stats.bySensitivity[item.sensitivityLevel] = (stats.bySensitivity[item.sensitivityLevel] || 0) + 1;
    }
    
    // Incrementa contadores por política de retenção
    if (item.retentionPolicy) {
      stats.byRetentionPolicy[item.retentionPolicy] = (stats.byRetentionPolicy[item.retentionPolicy] || 0) + 1;
    }
    
    // Incrementa contadores por fonte de dados
    if (item.source) {
      stats.bySource[item.source] = (stats.bySource[item.source] || 0) + 1;
    }
    
    // Incrementa contadores por status
    if (item.status) {
      stats.byStatus[item.status] = (stats.byStatus[item.status] || 0) + 1;
    }
    
    // Incrementa contadores por tipo de dados
    if (item.dataType) {
      stats.byType[item.dataType] = (stats.byType[item.dataType] || 0) + 1;
    }
    
    // Incrementa contadores por mecanismo de proteção
    if (item.protectionMethod) {
      stats.byProtection[item.protectionMethod] = (stats.byProtection[item.protectionMethod] || 0) + 1;
    }
    
    // Incrementa contadores por localização de armazenamento
    if (item.storageLocation) {
      stats.byLocation[item.storageLocation] = (stats.byLocation[item.storageLocation] || 0) + 1;
    }
    
    // Incrementa contadores por status de consentimento
    if (item.consentStatus) {
      stats.byConsent[item.consentStatus] = (stats.byConsent[item.consentStatus] || 0) + 1;
    }
    
    // Soma o tamanho total em bytes (se disponível)
    if (item.sizeBytes && typeof item.sizeBytes === 'number') {
      stats.totalSizeBytes += item.sizeBytes;
    }
  }
  
  return stats;
}

