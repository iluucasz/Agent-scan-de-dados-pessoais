// @ts-nocheck
import { Router } from 'express';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import crypto from 'crypto';
import { isAdmin, isAdminOrAgent } from '../access-control';
import { generateUniqueId } from '../utils';

const router = Router();

// Configuração do Multer para armazenamento de arquivos
const agentStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = path.join(process.cwd(), 'public', 'agent-downloads');
    // Garantir que o diretório existe
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    // Format: platform_architecture_version_uniquehash.zip
    const { platform, architecture, version } = req.body;
    const uniqueHash = crypto.randomBytes(8).toString('hex');
    const filename = `agent_${platform}_${architecture}_${version.replace(/\./g, '_')}_${uniqueHash}.zip`;
    cb(null, filename);
  }
});

const upload = multer({
  storage: agentStorage,
  limits: {
    fileSize: 150 * 1024 * 1024 // 150MB
  },
  fileFilter: (req, file, cb) => {
    // Aceitar apenas arquivos zip
    if (file.mimetype === 'application/zip' || file.originalname.endsWith('.zip')) {
      cb(null, true);
    } else {
      cb(new Error('Formato de arquivo inválido. Apenas arquivos ZIP são permitidos.'));
    }
  }
});

// Middleware de autenticação de admin
const versionsAuthMiddleware = isAdmin;

// Rota para upload de novas versões de agentes
router.post('/versions', versionsAuthMiddleware, upload.single('agentFile'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: 'Nenhum arquivo enviado' });
    }

    const { platform, architecture, version, releaseNotes } = req.body;
    
    if (!platform || !architecture || !version) {
      // Remover o arquivo se falhar a validação
      if (req.file.path && fs.existsSync(req.file.path)) {
        fs.unlinkSync(req.file.path);
      }
      return res.status(400).json({ message: 'Dados obrigatórios faltando: platform, architecture, version' });
    }

    // Calcular o hash sha256 do arquivo
    const fileBuffer = fs.readFileSync(req.file.path);
    const checksumSha256 = crypto.createHash('sha256').update(fileBuffer).digest('hex');

    // URL relativa para download
    const fileUrl = `/agent-downloads/${path.basename(req.file.path)}`;
    
    // Calcular o hash sha256 do arquivo
    const checksum = checksumSha256;
    
    // Adicionar a nova versão no armazenamento
    const newVersion = await storage.createAgentVersion({
      version,
      platform,
      architecture,
      fileUrl,
      checksum,
      releaseDate: new Date(),
      releaseNotes: releaseNotes || null,
      isActive: true,
      fileSize: req.file.size
    });

    res.status(201).json(newVersion);
  } catch (error) {
    console.error('Erro ao criar nova versão de agente:', error);
    // Remover o arquivo em caso de erro
    if (req.file && req.file.path && fs.existsSync(req.file.path)) {
      fs.unlinkSync(req.file.path);
    }
    res.status(500).json({ message: 'Erro ao processar upload da nova versão', error: error.message });
  }
});

// Rota para obter todas as versões de agentes
router.get('/versions', async (req, res) => {
  try {
    const { platform, architecture, active } = req.query;
    
    let versions;
    
    if (active === 'true' || active === '1') {
      versions = await storage.getAgentVersions(
        platform as string | undefined, 
        architecture as string | undefined
      );
      versions = versions.filter(v => v.isActive);
    } else {
      versions = await storage.getAgentVersions(
        platform as string | undefined, 
        architecture as string | undefined
      );
    }
    
    res.json(versions);
  } catch (error) {
    console.error('Erro ao buscar versões de agentes:', error);
    res.status(500).json({ message: 'Erro ao buscar versões de agentes', error: error.message });
  }
});

// Rota para obter uma versão específica de agente
router.get('/versions/:id', async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    if (isNaN(id)) {
      return res.status(400).json({ message: 'ID inválido' });
    }
    
    const version = await storage.getAgentVersion(id);
    if (!version) {
      return res.status(404).json({ message: 'Versão não encontrada' });
    }
    
    res.json(version);
  } catch (error) {
    console.error('Erro ao buscar versão de agente:', error);
    res.status(500).json({ message: 'Erro ao buscar versão de agente', error: error.message });
  }
});

// Rota para obter a versão mais recente de um agente para uma plataforma/arquitetura
router.get('/versions/latest/:platform/:architecture', async (req, res) => {
  try {
    const { platform, architecture } = req.params;
    const latestVersion = await storage.getLatestAgentVersion(platform, architecture);
    
    if (!latestVersion) {
      return res.status(404).json({ 
        message: `Nenhuma versão disponível para ${platform}/${architecture}` 
      });
    }
    
    res.json(latestVersion);
  } catch (error) {
    console.error('Erro ao buscar última versão de agente:', error);
    res.status(500).json({ message: 'Erro ao buscar última versão', error: error.message });
  }
});

// Rota para atualizar uma versão de agente (ativar/desativar)
router.patch('/versions/:id', versionsAuthMiddleware, async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    if (isNaN(id)) {
      return res.status(400).json({ message: 'ID inválido' });
    }
    
    const { isActive, releaseNotes } = req.body;
    
    // Validar quais campos estão sendo atualizados
    if (isActive === undefined && releaseNotes === undefined) {
      return res.status(400).json({ message: 'Nenhum campo válido para atualização' });
    }
    
    // Construir objeto de atualização apenas com campos fornecidos
    const updateData: any = {};
    if (isActive !== undefined) updateData.isActive = isActive;
    if (releaseNotes !== undefined) updateData.releaseNotes = releaseNotes;
    
    const updatedVersion = await storage.updateAgentVersion(id, updateData);
    
    if (!updatedVersion) {
      return res.status(404).json({ message: 'Versão não encontrada' });
    }
    
    res.json(updatedVersion);
  } catch (error) {
    console.error('Erro ao atualizar versão de agente:', error);
    res.status(500).json({ message: 'Erro ao atualizar versão', error: error.message });
  }
});

// Rota para excluir uma versão de agente
router.delete('/versions/:id', versionsAuthMiddleware, async (req, res) => {
  try {
    const id = parseInt(req.params.id);
    if (isNaN(id)) {
      return res.status(400).json({ message: 'ID inválido' });
    }
    
    // Obter versão para posteriormente excluir o arquivo
    const version = await storage.getAgentVersion(id);
    if (!version) {
      return res.status(404).json({ message: 'Versão não encontrada' });
    }
    
    // Excluir do armazenamento
    const deleted = await storage.deleteAgentVersion(id);
    
    if (!deleted) {
      return res.status(500).json({ message: 'Falha ao excluir versão' });
    }
    
    // Excluir o arquivo físico se existir
    if (version.fileUrl) {
      const filePath = path.join(process.cwd(), 'public', version.fileUrl.replace(/^\//, ''));
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }
    }
    
    res.status(204).send();
  } catch (error) {
    console.error('Erro ao excluir versão de agente:', error);
    res.status(500).json({ message: 'Erro ao excluir versão', error: error.message });
  }
});

// Middleware de autenticação para admin ou agente
const installedAgentsAuthMiddleware = isAdminOrAgent;

// Rota para obter agentes instalados
router.get('/installed', installedAgentsAuthMiddleware, async (req, res) => {
  try {
    const { organizationId, status, platform } = req.query;
    
    // Conversão de valores para os tipos corretos
    const orgId = organizationId ? parseInt(organizationId as string) : undefined;
    
    const agents = await storage.getInstalledAgents(
      isNaN(orgId as number) ? undefined : orgId,
      status as string | undefined,
      platform as string | undefined
    );
    
    res.json(agents);
  } catch (error) {
    console.error('Erro ao buscar agentes instalados:', error);
    res.status(500).json({ message: 'Erro ao buscar agentes instalados', error: error.message });
  }
});

// Outras rotas da Central de Agentes podem ser adicionadas aqui...

export default router;