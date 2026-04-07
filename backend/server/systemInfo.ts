import { exec } from 'child_process';
import { arch, cpus, freemem, hostname, networkInterfaces, platform, release, totalmem, uptime } from 'os';
import { promisify } from 'util';

const execPromise = promisify(exec);

/**
 * Utilitário para coletar informações reais do sistema
 * para uso na funcionalidade de descoberta de ativos de TI
 */
export class SystemInfoCollector {
  /**
   * Coleta informações básicas do sistema operacional
   */
  static async getSystemInfo(): Promise<any> {
    try {
      const cpuInfo = cpus();
      const cpuModel = cpuInfo.length > 0 ? cpuInfo[0].model : 'Desconhecido';
      const cpuCores = cpuInfo.length;
      
      const totalMemoryMB = Math.round(totalmem() / (1024 * 1024));
      const freeMemoryMB = Math.round(freemem() / (1024 * 1024));
      const usedMemoryMB = totalMemoryMB - freeMemoryMB;
      const memoryUsagePercent = Math.round((usedMemoryMB / totalMemoryMB) * 100);
      
      const systemUptime = Math.floor(uptime() / 3600); // uptime em horas
      
      return {
        hostname: hostname(),
        platform: platform(),
        arch: arch(),
        release: release(),
        cpuModel,
        cpuCores,
        totalMemoryMB,
        freeMemoryMB,
        usedMemoryMB,
        memoryUsagePercent,
        systemUptime
      };
    } catch (error) {
      console.error('Erro ao coletar informações do sistema:', error);
      return {
        error: 'Não foi possível coletar informações do sistema'
      };
    }
  }
  
  /**
   * Coleta informações de rede
   */
  static getNetworkInfo(): any {
    try {
      const interfaces = networkInterfaces();
      const networkData = [];
      
      for (const [name, nets] of Object.entries(interfaces)) {
        if (nets) {
          for (const net of nets) {
            // Ignorar endereços internos
            if (!net.internal) {
              networkData.push({
                name,
                address: net.address,
                netmask: net.netmask,
                family: net.family,
                mac: net.mac
              });
            }
          }
        }
      }
      
      return networkData;
    } catch (error) {
      console.error('Erro ao coletar informações de rede:', error);
      return [];
    }
  }
  
  /**
   * Lista processos em execução no sistema (os mais relevantes)
   */
  static async getRunningProcesses(): Promise<any[]> {
    try {
      const isWindows = platform() === 'win32';
      
      // Comando específico para cada plataforma para listar processos
      const command = isWindows
        ? 'powershell "Get-Process | Sort-Object -Property CPU -Descending | Select-Object -First 15 | ForEach-Object { $_.ProcessName + \\"|\\" + $_.Id + \\"|\\" + $_.CPU + \\"|\\" + $_.WorkingSet }"'
        : 'ps -eo pid,pcpu,pmem,comm --sort=-pcpu | head -16';
      
      const { stdout } = await execPromise(command);
      const lines = stdout.trim().split('\n');
      
      // Pular a linha de cabeçalho no Linux
      const startIndex = isWindows ? 0 : 1;
      const processes = [];
      
      for (let i = startIndex; i < lines.length; i++) {
        if (isWindows) {
          const [name, pid, cpu, memory] = lines[i].split('|');
          processes.push({
            name,
            pid: parseInt(pid),
            cpu: parseFloat(cpu) || 0,
            memory: parseInt(memory) / (1024 * 1024) // converter para MB
          });
        } else {
          const parts = lines[i].trim().split(/\\s+/);
          if (parts.length >= 4) {
            processes.push({
              pid: parseInt(parts[0]),
              cpu: parseFloat(parts[1]),
              memory: parseFloat(parts[2]),
              name: parts.slice(3).join(' ')
            });
          }
        }
      }
      
      return processes;
    } catch (error) {
      console.error('Erro ao coletar informações de processos:', error);
      return [];
    }
  }
  
  /**
   * Coleta informações de discos/volumes
   */
  static async getDiskInfo(): Promise<any[]> {
    try {
      const isWindows = platform() === 'win32';
      
      const command = isWindows
        ? 'powershell "Get-WmiObject -Class Win32_LogicalDisk | Select-Object DeviceID, DriveType, VolumeName, @{Name=\'Size\';Expression={[math]::round($_.Size/1GB, 2)}}, @{Name=\'FreeSpace\';Expression={[math]::round($_.FreeSpace/1GB, 2)}} | ConvertTo-Json"'
        : 'df -h --output=source,fstype,size,used,avail,pcent,target | grep -v tmp';
      
      const { stdout } = await execPromise(command);
      
      if (isWindows) {
        try {
          // Parse JSON output from PowerShell
          const disks = JSON.parse(stdout);
          return Array.isArray(disks) ? disks : [disks];
        } catch (e) {
          return [{error: 'Falha ao interpretar informações de disco'}];
        }
      } else {
        // Parse Linux df output
        const lines = stdout.trim().split('\n');
        const disks = [];
        
        // Pular a linha de cabeçalho
        for (let i = 1; i < lines.length; i++) {
          const parts = lines[i].trim().split(/\\s+/);
          if (parts.length >= 6) {
            disks.push({
              filesystem: parts[0],
              type: parts[1],
              size: parts[2],
              used: parts[3],
              available: parts[4],
              usePercent: parts[5],
              mountpoint: parts.slice(6).join(' ')
            });
          }
        }
        
        return disks;
      }
    } catch (error) {
      console.error('Erro ao coletar informações de disco:', error);
      return [];
    }
  }
  
  /**
   * Obtem informações de software instalados (apenas os principais)
   */
  static async getInstalledSoftware(): Promise<any[]> {
    try {
      const isWindows = platform() === 'win32';
      
      if (isWindows) {
        const command = 'powershell "Get-ItemProperty HKLM:\\\\Software\\\\Wow6432Node\\\\Microsoft\\\\Windows\\\\CurrentVersion\\\\Uninstall\\\\* | Select-Object DisplayName, DisplayVersion, Publisher | Where-Object {$_.DisplayName} | ConvertTo-Json"';
        
        try {
          const { stdout } = await execPromise(command);
          const apps = JSON.parse(stdout);
          return Array.isArray(apps) ? apps.slice(0, 20) : [apps]; // Limitar para 20 aplicativos
        } catch (e) {
          return [{name: 'Não foi possível listar aplicativos no Windows'}];
        }
      } else {
        // Em sistemas Linux, listamos aplicativos comuns
        const command = 'which nginx apache2 mysql postgresql nodejs npm python3 docker docker-compose go java ruby php maven gradle htop nano vim git 2>/dev/null';
        
        const { stdout } = await execPromise(command);
        const installedPaths = stdout.trim().split('\n').filter(Boolean);
        
        const software = [];
        for (const path of installedPaths) {
          const name = path.split('/').pop();
          
          // Tentar obter a versão para cada aplicativo
          try {
            let versionCommand;
            let versionParser;
            
            switch (name) {
              case 'nginx':
                versionCommand = 'nginx -v 2>&1';
                versionParser = (out: string) => out.match(/nginx version: nginx\/(\d+\.\d+\.\d+)/)?.[1] || 'Desconhecida';
                break;
              case 'apache2':
                versionCommand = 'apache2 -v 2>&1';
                versionParser = (out: string) => out.match(/Apache\/(\d+\.\d+)/)?.[1] || 'Desconhecida';
                break;
              case 'mysql':
                versionCommand = 'mysql --version';
                versionParser = (out: string) => out.match(/Ver ([\d\.]+)/)?.[1] || 'Desconhecida';
                break;
              case 'postgresql':
                versionCommand = 'psql --version';
                versionParser = (out: string) => out.match(/\d+\.\d+/)?.[0] || 'Desconhecida';
                break;
              case 'nodejs':
              case 'node':
                versionCommand = 'node --version';
                versionParser = (out: string) => out.trim().replace('v', '');
                break;
              case 'npm':
                versionCommand = 'npm --version';
                versionParser = (out: string) => out.trim();
                break;
              case 'python3':
                versionCommand = 'python3 --version';
                versionParser = (out: string) => out.match(/Python (\d+\.\d+\.\d+)/)?.[1] || 'Desconhecida';
                break;
              case 'docker':
                versionCommand = 'docker --version';
                versionParser = (out: string) => out.match(/Docker version ([\d\.]+)/)?.[1] || 'Desconhecida';
                break;
              case 'java':
                versionCommand = 'java -version 2>&1';
                versionParser = (out: string) => out.match(/version "([^"]+)"/)?.[1] || 'Desconhecida';
                break;
              default:
                versionCommand = `${name} --version 2>&1`;
                versionParser = (out: string) => out.trim().split('\n')[0].substring(0, 20);
            }
            
            const { stdout: versionOutput } = await execPromise(versionCommand);
            const version = versionParser(versionOutput);
            
            software.push({
              name,
              version,
              path
            });
          } catch (e) {
            // Se não conseguir obter a versão, adicionar apenas o nome
            software.push({
              name,
              version: 'Desconhecida',
              path
            });
          }
        }
        
        return software;
      }
    } catch (error) {
      console.error('Erro ao coletar informações de software:', error);
      return [{name: 'Erro ao listar aplicativos', error: error.message}];
    }
  }
  
  /**
   * Converte as informações do sistema para o formato ITAsset
   * para uso nas funções de mapeamento de dados
   */
  static async getSystemInfoAsITAssets(organizationId: number): Promise<any[]> {
    const assets: any[] = [];
    const timestamp = new Date();
    let assetId = 1;
    
    try {
      // 1. Informações do sistema principal
      const sysInfo = await this.getSystemInfo();
      const hostname = sysInfo.hostname || 'servidor';
      
      assets.push({
        id: assetId++,
        createdAt: timestamp,
        updatedAt: timestamp,
        type: 'server',
        name: `Servidor ${hostname}`,
        organizationId,
        description: `Servidor executando ${sysInfo.platform} ${sysInfo.release} (${sysInfo.arch})`,
        location: 'Datacenter',
        owner: 'TI',
        dataClassifications: {
          types: ['technical', 'operational'],
          sensitivity: 'low'
        },
        securityMeasures: 'Firewall, Atualizações Automáticas',
        status: 'active',
        manufacturer: 'Vários',
        model: `CPU: ${sysInfo.cpuModel || 'Desconhecido'}`,
        serialNumber: null,
        operatingSystem: `${sysInfo.platform} ${sysInfo.release}`,
        ipAddress: '127.0.0.1',
        macAddress: null,
        lastInventoryDate: timestamp,
        specifications: {
          cpu: {
            model: sysInfo.cpuModel,
            cores: sysInfo.cpuCores
          },
          memory: {
            totalMB: sysInfo.totalMemoryMB,
            usedMB: sysInfo.usedMemoryMB,
            usagePercent: sysInfo.memoryUsagePercent
          },
          uptime: {
            hours: sysInfo.systemUptime
          }
        }
      });
      
      // 2. Informações de rede
      const networkInfo = this.getNetworkInfo();
      
      if (networkInfo && networkInfo.length > 0) {
        assets.push({
          id: assetId++,
          createdAt: timestamp,
          updatedAt: timestamp,
          type: 'network',
          name: 'Interfaces de Rede',
          organizationId,
          description: `Configuração de rede do servidor ${hostname}`,
          location: 'Datacenter',
          owner: 'TI',
          dataClassifications: {
            types: ['technical', 'configuration'],
            sensitivity: 'medium'
          },
          securityMeasures: 'Firewall, IDS',
          status: 'active',
          manufacturer: 'Vários',
          model: 'Vários',
          serialNumber: null,
          operatingSystem: null,
          ipAddress: networkInfo[0]?.address || '127.0.0.1',
          macAddress: networkInfo[0]?.mac || null,
          lastInventoryDate: timestamp,
          specifications: {
            interfaces: networkInfo
          }
        });
      }
      
      // 3. Informações de disco
      const diskInfo = await this.getDiskInfo();
      
      if (diskInfo && diskInfo.length > 0) {
        assets.push({
          id: assetId++,
          createdAt: timestamp,
          updatedAt: timestamp,
          type: 'storage',
          name: 'Discos e Armazenamento',
          organizationId,
          description: `Armazenamento do servidor ${hostname}`,
          location: 'Datacenter',
          owner: 'TI',
          dataClassifications: {
            types: ['technical', 'data_storage'],
            sensitivity: 'high'
          },
          securityMeasures: 'Backup diário, Monitoramento',
          status: 'active',
          manufacturer: 'Vários',
          model: 'Vários',
          serialNumber: null,
          operatingSystem: null,
          ipAddress: null,
          macAddress: null,
          lastInventoryDate: timestamp,
          specifications: {
            disks: diskInfo
          }
        });
      }
      
      // 4. Software instalado
      const softwareInfo = await this.getInstalledSoftware();
      
      if (softwareInfo && softwareInfo.length > 0) {
        assets.push({
          id: assetId++,
          createdAt: timestamp,
          updatedAt: timestamp,
          type: 'software',
          name: 'Software Instalado',
          organizationId,
          description: `Aplicativos e serviços instalados no servidor ${hostname}`,
          location: 'Datacenter',
          owner: 'TI',
          dataClassifications: {
            types: ['technical', 'software'],
            sensitivity: 'medium'
          },
          securityMeasures: 'Atualizações automáticas, Monitoramento de vulnerabilidades',
          status: 'active',
          manufacturer: 'Vários',
          model: null,
          serialNumber: null,
          operatingSystem: `${sysInfo.platform} ${sysInfo.release}`,
          ipAddress: null,
          macAddress: null,
          lastInventoryDate: timestamp,
          specifications: {
            applications: softwareInfo
          }
        });
      }
      
      // 5. Processos em execução
      const processInfo = await this.getRunningProcesses();
      
      if (processInfo && processInfo.length > 0) {
        assets.push({
          id: assetId++,
          createdAt: timestamp,
          updatedAt: timestamp,
          type: 'process',
          name: 'Processos em Execução',
          organizationId,
          description: `Processos principais em execução no servidor ${hostname}`,
          location: 'Datacenter',
          owner: 'TI',
          dataClassifications: {
            types: ['technical', 'operational'],
            sensitivity: 'medium'
          },
          securityMeasures: 'Monitoramento, Controle de acesso',
          status: 'active',
          manufacturer: null,
          model: null,
          serialNumber: null,
          operatingSystem: `${sysInfo.platform} ${sysInfo.release}`,
          ipAddress: null,
          macAddress: null,
          lastInventoryDate: timestamp,
          specifications: {
            processes: processInfo
          }
        });
      }
      
      return assets;
    } catch (error) {
      console.error('Erro ao converter informações do sistema para ativos de TI:', error);
      
      // Retornar pelo menos um ativo com informações do erro para debug
      return [{
        id: 1,
        createdAt: timestamp,
        updatedAt: timestamp,
        type: 'server',
        name: 'Erro ao coletar informações',
        organizationId,
        description: `Ocorreu um erro ao coletar informações do sistema: ${error.message}`,
        location: 'Desconhecido',
        owner: 'TI',
        dataClassifications: null,
        securityMeasures: null,
        status: 'inactive',
        manufacturer: null,
        model: null,
        serialNumber: null,
        operatingSystem: platform(),
        ipAddress: null,
        macAddress: null,
        lastInventoryDate: timestamp,
        specifications: {
          error: error.message,
          stack: error.stack
        }
      }];
    }
  }
}