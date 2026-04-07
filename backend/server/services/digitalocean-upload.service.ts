import axios from 'axios';
import crypto from 'crypto';
import path from 'path';
import { lookup } from 'mime-types';

interface UploadResult {
  filename: string;
  originalName: string;
  size: number;
  uploadUrl: string;
  cdnUrl: string;
  status: 'success' | 'error';
  error?: string;
  contentType: string;
  uploadTime?: number;
}

interface BatchUploadResult {
  scanName: string;
  folderName: string;
  totalFiles: number;
  successfulUploads: number;
  failedUploads: number;
  results: UploadResult[];
  duration: number;
  timestamp: string;
}

export class DigitalOceanUploadService {
  private readonly endpoint: string;
  private readonly bucket: string;
  private readonly region: string;
  private readonly accessKey: string;
  private readonly secretKey: string;
  private readonly cdnUrl: string;

  constructor() {
    this.endpoint = process.env.SPACES_ENDPOINT || 'https://nyc3.digitaloceanspaces.com';
    this.bucket = process.env.SPACES_BUCKET || 'privacypulse';
    this.region = process.env.SPACES_REGION || 'nyc3';
    this.accessKey = process.env.SPACES_KEY!;
    this.secretKey = process.env.SPACES_SECRET!;
    this.cdnUrl = process.env.SPACES_CDN_URL || 'https://privacypulse.nyc3.cdn.digitaloceanspaces.com';

    if (!this.accessKey || !this.secretKey) {
      throw new Error('DigitalOcean Spaces credentials not configured. Check SPACES_KEY and SPACES_SECRET environment variables.');
    }
  }

  /**
   * Upload sequencial de múltiplos arquivos para DigitalOcean Spaces
   * @param files - Array de arquivos do Multer
   * @param scanName - Nome do scan fornecido pelo usuário
   * @returns Resultado do upload batch com detalhes de cada arquivo
   */
  async uploadScanFiles(files: Express.Multer.File[], scanName: string): Promise<BatchUploadResult> {
    const startTime = Date.now();
    const results: UploadResult[] = [];
    
    console.log(`🚀 [DigitalOcean] Iniciando upload sequencial de ${files.length} arquivo(s)`);
    console.log(`📁 [DigitalOcean] Scan Name: "${scanName}"`);
    
    // Validar scanName
    if (!scanName || scanName.trim().length === 0) {
      throw new Error('scanName é obrigatório para upload');
    }

    // Normalizar o nome do scan para usar como pasta
    const folderName = this.normalizeScanName(scanName);
    console.log(`📂 [DigitalOcean] Pasta normalizada: "${folderName}"`);
    
    // Processar arquivos sequencialmente (1 por vez)
    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      console.log(`📤 [DigitalOcean] Processando arquivo ${i + 1}/${files.length}: ${file.originalname}`);
      
      try {
        const uploadStartTime = Date.now();
        const result = await this.uploadSingleFile(file, folderName);
        result.uploadTime = Date.now() - uploadStartTime;
        
        results.push(result);
        console.log(`✅ [DigitalOcean] Upload concluído: ${file.originalname} (${result.uploadTime}ms)`);
      } catch (error) {
        console.error(`❌ [DigitalOcean] Erro no upload de ${file.originalname}:`, error);
        results.push({
          filename: file.originalname,
          originalName: file.originalname,
          size: file.size,
          uploadUrl: '',
          cdnUrl: '',
          status: 'error',
          error: error instanceof Error ? error.message : 'Erro desconhecido',
          contentType: file.mimetype || 'application/octet-stream'
        });
      }
    }

    const duration = Date.now() - startTime;
    const successfulUploads = results.filter(r => r.status === 'success').length;
    const failedUploads = results.filter(r => r.status === 'error').length;

    console.log(`📊 [DigitalOcean] Upload finalizado em ${duration}ms`);
    console.log(`📈 [DigitalOcean] Sucessos: ${successfulUploads}, Falhas: ${failedUploads}`);

    return {
      scanName,
      folderName,
      totalFiles: files.length,
      successfulUploads,
      failedUploads,
      results,
      duration,
      timestamp: new Date().toISOString()
    };
  }

  /**
   * Upload de um único arquivo para DigitalOcean Spaces via PUT request
   * OTIMIZADO: Trabalha diretamente com file.buffer (sem I/O de disco)
   */
  private async uploadSingleFile(file: Express.Multer.File, folderName: string): Promise<UploadResult> {
    // Detectar content-type
    const contentType = file.mimetype || lookup(file.originalname) || 'application/octet-stream';
    
    // Construir URLs corretamente para DigitalOcean Spaces
    const fileName = file.originalname;
    const uploadPath = `${folderName}/${fileName}`;
    
    // URL correta: https://privacypulse.nyc3.digitaloceanspaces.com/pasta/arquivo
    const uploadUrl = `https://${this.bucket}.${this.region}.digitaloceanspaces.com/${uploadPath}`;
    const cdnUrl = `${this.cdnUrl}/${uploadPath}`;
    
    // Host correto para assinatura AWS v4
    const hostHeader = `${this.bucket}.${this.region}.digitaloceanspaces.com`;

    console.log(`🔗 [DigitalOcean] Upload URL: ${uploadUrl}`);
    console.log(`🌐 [DigitalOcean] CDN URL: ${cdnUrl}`);
    console.log(`🏠 [DigitalOcean] Host Header: ${hostHeader}`);

    // Usar buffer direto do Multer (memoryStorage)
    if (!file.buffer) {
      throw new Error(`Buffer do arquivo não encontrado para: ${file.originalname}`);
    }

    const fileBuffer = file.buffer;
    const contentLength = fileBuffer.length;

    console.log(`📦 [DigitalOcean] Arquivo: ${file.originalname}, Tamanho: ${contentLength} bytes`);

    // Gerar timestamp primeiro
    const now = new Date();
    const dateStamp = now.toISOString().slice(0, 10).replace(/-/g, '');
    const timeStamp = now.toISOString().slice(0, 19).replace(/[-:]/g, '') + 'Z';

    // Preparar headers para assinatura AWS v4 (incluindo X-Amz-Date e x-amz-content-sha256)
    const bodyHash = crypto.createHash('sha256').update(fileBuffer).digest('hex');
    const headers = {
      'Content-Type': contentType,
      'Host': hostHeader,
      'x-amz-acl': 'public-read',
      'X-Amz-Date': timeStamp,
      'x-amz-content-sha256': bodyHash
    };

    // Gerar assinatura AWS v4
    const signedHeaders = this.generateAWSv4Signature('PUT', uploadPath, headers, fileBuffer);

    try {
      // Fazer requisição PUT para DigitalOcean Spaces
      const response = await axios.put(uploadUrl, fileBuffer, {
        headers: {
          'Content-Type': contentType,
          'Content-Length': signedHeaders['Content-Length'],
          'Host': hostHeader,
          'x-amz-acl': 'public-read',
          'x-amz-content-sha256': signedHeaders['x-amz-content-sha256'],
          'Authorization': signedHeaders.Authorization,
          'X-Amz-Date': signedHeaders['X-Amz-Date']
        },
        maxBodyLength: Infinity,
        maxContentLength: Infinity,
        timeout: 120000 // 2 minutos timeout
      });

      console.log(`📤 [DigitalOcean] Response status: ${response.status} for ${fileName}`);
      console.log(`📏 [DigitalOcean] File size: ${(contentLength / 1024 / 1024).toFixed(2)}MB`);

      return {
        filename: fileName,
        originalName: file.originalname,
        size: file.size,
        uploadUrl,
        cdnUrl,
        status: 'success',
        contentType
      };

    } catch (error: any) {
      console.error(`❌ [DigitalOcean] Erro no upload para ${uploadUrl}:`, {
        status: error.response?.status,
        statusText: error.response?.statusText,
        data: error.response?.data,
        message: error.message
      });
      
      let errorMessage = 'Falha no upload';
      if (error.response) {
        errorMessage = `HTTP ${error.response.status}: ${error.response.statusText}`;
      } else if (error.code === 'ECONNABORTED') {
        errorMessage = 'Timeout no upload - arquivo muito grande ou conexão lenta';
      } else {
        errorMessage = error.message;
      }
      
      throw new Error(errorMessage);
    }
  }

  /**
   * Normaliza o nome do scan para usar como nome de pasta
   * Remove caracteres especiais e converte para lowercase
   * Exemplo: "escaneamento TI 11/07/2025" -> "escaneamentoti11072025"
   */
  private normalizeScanName(scanName: string): string {
    return scanName
      .toLowerCase()
      .replace(/[^a-z0-9]/g, '') // Remove todos os caracteres que não são letras ou números
      .trim();
  }

  /**
   * Gera assinatura AWS v4 para autenticação no DigitalOcean Spaces
   * Seguindo exatamente o padrão da documentação oficial
   */
  private generateAWSv4Signature(
    method: string, 
    path: string, 
    headers: Record<string, string>, 
    body: Buffer
  ): Record<string, string> {
    // Usar o timestamp já presente nos headers
    const amzDate = headers['X-Amz-Date'];
    const dateStamp = amzDate.slice(0, 8); // Extrair YYYYMMDD
    
    // Garantir que o path comece com /
    const canonicalPath = path.startsWith('/') ? path : `/${path}`;
    
    // Content-Length é obrigatório na assinatura conforme documentação
    const contentLength = body.length.toString();
    
    // Headers para canonical request - TODOS os headers da requisição devem estar aqui
    // Ordem alfabética rigorosa conforme documentação
    const canonicalHeaders = [
      `content-length:${contentLength}`,
      `content-type:${headers['Content-Type']}`,
      `host:${headers['Host']}`,
      `x-amz-acl:${headers['x-amz-acl']}`,
      `x-amz-content-sha256:${headers['x-amz-content-sha256']}`,
      `x-amz-date:${amzDate}`
    ].join('\n') + '\n';
    
    const signedHeaders = 'content-length;content-type;host;x-amz-acl;x-amz-content-sha256;x-amz-date';
    
    // Hash do body
    const bodyHash = crypto.createHash('sha256').update(body).digest('hex');
    
    // Canonical request seguindo formato exato da documentação
    const canonicalRequest = [
      method,
      canonicalPath,
      '', // query string vazia (mas linha deve estar presente)
      canonicalHeaders,
      signedHeaders,
      bodyHash
    ].join('\n');

    // Credential scope
    const credentialScope = `${dateStamp}/${this.region}/s3/aws4_request`;
    
    // String to sign
    const algorithm = 'AWS4-HMAC-SHA256';
    const stringToSign = [
      algorithm,
      amzDate,
      credentialScope,
      crypto.createHash('sha256').update(canonicalRequest, 'utf8').digest('hex')
    ].join('\n');

    // Gerar chave de assinatura
    const kDate = crypto.createHmac('sha256', `AWS4${this.secretKey}`).update(dateStamp).digest();
    const kRegion = crypto.createHmac('sha256', kDate).update(this.region).digest();
    const kService = crypto.createHmac('sha256', kRegion).update('s3').digest();
    const kSigning = crypto.createHmac('sha256', kService).update('aws4_request').digest();
    
    // Calcular assinatura
    const signature = crypto.createHmac('sha256', kSigning).update(stringToSign, 'utf8').digest('hex');

    // Authorization header
    const authorization = `${algorithm} Credential=${this.accessKey}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`;

    return {
      'Authorization': authorization,
      'X-Amz-Date': amzDate,
      'Content-Length': contentLength,
      'x-amz-content-sha256': headers['x-amz-content-sha256']
    };
  }

  /**
   * Verifica se um arquivo existe no DigitalOcean Spaces
   */
  async fileExists(folderName: string, fileName: string): Promise<boolean> {
    try {
      const cdnUrl = `${this.cdnUrl}/${folderName}/${fileName}`;
      const response = await axios.head(cdnUrl, { timeout: 10000 });
      return response.status === 200;
    } catch (error) {
      return false;
    }
  }

  /**
   * Gera URL CDN para um arquivo
   */
  generateCdnUrl(folderName: string, fileName: string): string {
    return `${this.cdnUrl}/${folderName}/${fileName}`;
  }

  /**
   * Validar configuração do serviço
   */
  validateConfiguration(): { valid: boolean; errors: string[] } {
    const errors: string[] = [];

    if (!this.accessKey) errors.push('SPACES_KEY não configurado');
    if (!this.secretKey) errors.push('SPACES_SECRET não configurado');
    if (!this.endpoint) errors.push('SPACES_ENDPOINT não configurado');
    if (!this.bucket) errors.push('SPACES_BUCKET não configurado');
    if (!this.region) errors.push('SPACES_REGION não configurado');
    if (!this.cdnUrl) errors.push('SPACES_CDN_URL não configurado');

    return {
      valid: errors.length === 0,
      errors
    };
  }
}