import { OrganizationController } from '../server/controllers/organization.controller';

class FakeOrgService {
  async getById(id: number) { return { id, name: 'x' }; }
  async setCurrentOrganization(userId: string, organizationId: number) {
    return { currentOrganizationId: organizationId };
  }
}

function makeRes() {
  const res: any = { statusCode: 200, payload: undefined };
  res.status = function(code: number) { this.statusCode = code; return this; };
  res.json = function(payload: any) { this.payload = payload; return this; };
  return res;
}

export async function testOrganizationSwitchController() {
  const controller = new OrganizationController(new FakeOrgService() as any);

  // forbidden when org not allowed
  {
    const req: any = { user: { id: 'u1', role: 'gestor' }, body: { organizationId: 5 }, orgScope: { allowedOrgIds: [1,2,3] } };
    const res = makeRes();
    await controller.switchActive(req, res as any);
    if (res.statusCode !== 403) throw new Error('switch should be 403 when org not allowed');
  }

  // allowed when included
  {
    const req: any = { user: { id: 'u1', role: 'gestor' }, body: { organizationId: 2 }, orgScope: { allowedOrgIds: [1,2,3] } };
    const res = makeRes();
    await controller.switchActive(req, res as any);
    if (res.statusCode !== 200) throw new Error('switch should be 200 when allowed');
    if (!res.payload?.success || res.payload.currentOrganizationId !== 2) {
      throw new Error('switch response payload invalid');
    }
  }
}
