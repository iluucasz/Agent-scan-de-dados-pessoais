import { PersonalDataModuleController } from '../server/controllers/personal-data-module.controller';
import { AreasController } from '../server/controllers/areas.controller';
import { ProcessosController } from '../server/controllers/processos.controller';

// --- Helpers
function makeRes() {
  const res: any = { statusCode: 200, payload: undefined };
  res.status = function(code: number) { this.statusCode = code; return this; };
  res.json = function(payload: any) { this.payload = payload; return this; };
  res.send = function(payload?: any) { this.payload = payload; return this; };
  return res;
}

// --- Fakes
class FakePersonalService { lastOrg?: number; async getAll(orgId: number) { this.lastOrg = orgId; return [{ id: 1, organizationId: orgId }]; } async getStats(orgId: number) { this.lastOrg = orgId; return { orgId }; } async getById(id: number) { return { id, organizationId: 2 }; } async create(data: any) { return data; } async update(id: number, d: any) { return { id, ...d }; } async delete(id: number) { return true; } }
class FakeAreasService { async list() { return [{ id: 1 }]; } async findByOrganization(orgId: number) { return [{ id: 1, organizationId: orgId }]; } async create(d: any) { return d; } async getById(id: number) { return { id, organizationId: 2 }; } async update(id: number, d: any) { return { id, ...d }; } async delete(id: number) { return; } async getAreasWithProcessos(orgId: number) { return []; } }
class FakeProcessosService { lastOrg?: number; async list() { return [{ id: 1 }]; } async findByOrganization(orgId: number) { this.lastOrg = orgId; return [{ id: 1, organizationId: orgId }]; } async getById(id: number) { return { id, organizationId: 2 }; } async create(d: any) { return d; } async update(id: number, d: any) { return { id, ...d }; } async delete(id: number) { return; } async findByArea(areaId: number) { return []; } }

export async function testSmoke_PersonalData_UsesCurrentOrg() {
  const fake = new FakePersonalService();
  const controller = new PersonalDataModuleController(fake as any);
  const req: any = { user: { id: 'u', role: 'gestor', organizationId: 99 }, orgScope: { currentOrganizationId: 7 } };
  const res = makeRes();
  await controller.getAll(req as any, res as any);
  if (fake.lastOrg !== 7) throw new Error('PersonalData should use currentOrganizationId');
}

export async function testSmoke_Areas_ListByOrganization_EnforcesCurrentOrg() {
  const controller = new AreasController(new FakeAreasService() as any);
  // mismatch → 403
  {
    const req: any = { user: { role: 'gestor', organizationId: 2 }, orgScope: { currentOrganizationId: 2 }, params: { organizationId: '3' } };
    const res = makeRes();
    await controller.listByOrganization(req as any, res as any);
    if (res.statusCode !== 403) throw new Error('Areas listByOrganization should 403 when org mismatch');
  }
  // match → 200
  {
    const req: any = { user: { role: 'gestor', organizationId: 2 }, orgScope: { currentOrganizationId: 2 }, params: { organizationId: '2' } };
    const res = makeRes();
    await controller.listByOrganization(req as any, res as any);
    if (res.statusCode !== 200) throw new Error('Areas listByOrganization should 200 when org matches');
  }
}

export async function testSmoke_Processos_List_UsesCurrentOrg() {
  const fake = new FakeProcessosService();
  const controller = new ProcessosController(fake as any);
  const req: any = { user: { role: 'cliente', organizationId: 5 }, orgScope: { currentOrganizationId: 11 } };
  const res = makeRes();
  await controller.list(req as any, res as any);
  if (fake.lastOrg !== 11) throw new Error('Processos list should use currentOrganizationId for non-admin');
}
