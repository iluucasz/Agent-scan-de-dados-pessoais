/**
 * Rotas de métricas e estatísticas do sistema
 * Consolida todas as métricas em um endpoint centralizado
 */

import { Router, Request, Response } from 'express';
import { isAuthenticated, isAdmin } from '../access-control';
import { ScanDataModuleService } from '../services/scan-data-module.service';

const router = Router();
const scanService = new ScanDataModuleService();

/**
 * GET /api/metrics/system
 * Métricas gerais do sistema
 */
router.get('/system', isAuthenticated, async (req: Request, res: Response) => {
  try {
    const session = req.user as any;
    const orgId = session.organizationId;
    const isAdminUser = session.role === 'admin';

    // Buscar estatísticas de jobs
    const jobs = isAdminUser 
      ? await scanService.getDataScanJobs()
      : await scanService.getDataScanJobs(orgId);

    // Calcular métricas
    const totalJobs = jobs.length;
    const completedJobs = jobs.filter(j => j.status === 'completed').length;
    const failedJobs = jobs.filter(j => j.status === 'failed').length;
    const inProgressJobs = jobs.filter(j => j.status === 'in_progress').length;

    // Estatísticas de dados encontrados
    const totalDataItems = jobs
      .filter(j => j.foundItems && Array.isArray(j.foundItems))
      .reduce((sum, j) => sum + j.foundItems.length, 0);

    // Estatísticas por tipo de dado
    const dataTypeStats: Record<string, number> = {};
    jobs.forEach(job => {
      if (job.foundItems && Array.isArray(job.foundItems)) {
        job.foundItems.forEach((item: any) => {
          const type = item.dataType || 'unknown';
          dataTypeStats[type] = (dataTypeStats[type] || 0) + 1;
        });
      }
    });

    // Estatísticas de arquivos processados
    const totalFiles = jobs
      .filter(j => j.stats?.totalFiles)
      .reduce((sum, j) => sum + (j.stats.totalFiles || 0), 0);

    const response = {
      success: true,
      timestamp: new Date().toISOString(),
      organizationId: isAdminUser ? 'all' : orgId,
      metrics: {
        jobs: {
          total: totalJobs,
          completed: completedJobs,
          failed: failedJobs,
          inProgress: inProgressJobs,
          successRate: totalJobs > 0 ? Math.round((completedJobs / totalJobs) * 100) : 0
        },
        data: {
          totalItemsFound: totalDataItems,
          averageItemsPerJob: totalJobs > 0 ? Math.round(totalDataItems / totalJobs) : 0,
          typeBreakdown: dataTypeStats
        },
        files: {
          totalProcessed: totalFiles,
          averageFilesPerJob: totalJobs > 0 ? Math.round(totalFiles / totalJobs) : 0
        },
        performance: {
          avgProcessingTime: jobs
            .filter(j => j.startedAt && j.completedAt)
            .reduce((avg, j, _, arr) => {
              const duration = new Date(j.completedAt!).getTime() - new Date(j.startedAt).getTime();
              return avg + (duration / arr.length);
            }, 0)
        }
      }
    };

    res.json(response);
  } catch (error) {
    console.error('Error getting system metrics:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Erro ao buscar métricas do sistema',
      error: error instanceof Error ? error.message : 'Erro desconhecido'
    });
  }
});

/**
 * GET /api/metrics/jobs
 * Métricas específicas de jobs de scan
 */
router.get('/jobs', isAuthenticated, async (req: Request, res: Response) => {
  try {
    const session = req.user as any;
    const orgId = session.organizationId;
    const isAdminUser = session.role === 'admin';

    const jobs = isAdminUser 
      ? await scanService.getDataScanJobs()
      : await scanService.getDataScanJobs(orgId);

    // Agrupar por data (últimos 30 dias)
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const recentJobs = jobs.filter(j => 
      new Date(j.startedAt) >= thirtyDaysAgo
    );

    // Agrupar por dia
    const jobsByDay: Record<string, number> = {};
    recentJobs.forEach(job => {
      const day = new Date(job.startedAt).toISOString().split('T')[0];
      jobsByDay[day] = (jobsByDay[day] || 0) + 1;
    });

    // Top 5 configurações mais usadas
    const configUsage: Record<number, { count: number, configId: number }> = {};
    jobs.forEach(job => {
      const configId = job.configId;
      if (!configUsage[configId]) {
        configUsage[configId] = { count: 0, configId };
      }
      configUsage[configId].count++;
    });

    const topConfigs = Object.values(configUsage)
      .sort((a, b) => b.count - a.count)
      .slice(0, 5);

    res.json({
      success: true,
      timestamp: new Date().toISOString(),
      organizationId: isAdminUser ? 'all' : orgId,
      metrics: {
        timeline: {
          thirtyDayTrend: jobsByDay,
          totalRecentJobs: recentJobs.length
        },
        configurations: {
          topUsedConfigs: topConfigs,
          totalConfigs: Object.keys(configUsage).length
        },
        status: {
          completed: jobs.filter(j => j.status === 'completed').length,
          failed: jobs.filter(j => j.status === 'failed').length,
          inProgress: jobs.filter(j => j.status === 'in_progress').length
        }
      }
    });
  } catch (error) {
    console.error('Error getting job metrics:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Erro ao buscar métricas de jobs' 
    });
  }
});

/**
 * GET /api/metrics/data-types
 * Métricas de tipos de dados encontrados
 */
router.get('/data-types', isAuthenticated, async (req: Request, res: Response) => {
  try {
    const session = req.user as any;
    const orgId = session.organizationId;
    const isAdminUser = session.role === 'admin';

    const jobs = isAdminUser 
      ? await scanService.getDataScanJobs()
      : await scanService.getDataScanJobs(orgId);

    // Contar por tipo de dado e categoria
    const typeStats: Record<string, { count: number, category: string }> = {};
    const categoryStats: Record<string, number> = {};

    jobs.forEach(job => {
      if (job.foundItems && Array.isArray(job.foundItems)) {
        job.foundItems.forEach((item: any) => {
          const type = item.dataType || 'unknown';
          const category = item.category || 'unknown';

          if (!typeStats[type]) {
            typeStats[type] = { count: 0, category };
          }
          typeStats[type].count++;

          categoryStats[category] = (categoryStats[category] || 0) + 1;
        });
      }
    });

    res.json({
      success: true,
      timestamp: new Date().toISOString(),
      organizationId: isAdminUser ? 'all' : orgId,
      metrics: {
        byType: Object.entries(typeStats)
          .sort(([,a], [,b]) => b.count - a.count)
          .reduce((acc, [type, data]) => ({ ...acc, [type]: data }), {}),
        byCategory: Object.entries(categoryStats)
          .sort(([,a], [,b]) => b - a)
          .reduce((acc, [cat, count]) => ({ ...acc, [cat]: count }), {}),
        summary: {
          totalTypes: Object.keys(typeStats).length,
          totalCategories: Object.keys(categoryStats).length,
          mostCommonType: Object.entries(typeStats)
            .sort(([,a], [,b]) => b.count - a.count)[0]?.[0] || 'none'
        }
      }
    });
  } catch (error) {
    console.error('Error getting data type metrics:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Erro ao buscar métricas de tipos de dados' 
    });
  }
});

/**
 * GET /api/metrics/health
 * Health check com métricas básicas
 */
router.get('/health', async (req: Request, res: Response) => {
  try {
    const uptime = process.uptime();
    const memoryUsage = process.memoryUsage();

    res.json({
      success: true,
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: {
        seconds: Math.floor(uptime),
        human: `${Math.floor(uptime / 3600)}h ${Math.floor((uptime % 3600) / 60)}m ${Math.floor(uptime % 60)}s`
      },
      memory: {
        used: Math.round(memoryUsage.heapUsed / 1024 / 1024),
        total: Math.round(memoryUsage.heapTotal / 1024 / 1024),
        external: Math.round(memoryUsage.external / 1024 / 1024),
        unit: 'MB'
      },
      environment: {
        nodeVersion: process.version,
        platform: process.platform,
        arch: process.arch
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      status: 'unhealthy',
      error: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

export default router;
