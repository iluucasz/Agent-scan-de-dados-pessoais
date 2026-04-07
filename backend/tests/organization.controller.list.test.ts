import { OrganizationController } from '../server/controllers/organization.controller';

class FakeOrgServiceList {
  async list() { return [{ id: 1, name: 'A' }, { id: 2, name: 'B' }, { id: 3, name: 'C' }]; }
}

function makeRes() {
  const res: any = { statusCode: 200, payload: undefined };
  res.status = function(code: number) { this.statusCode = code; return this; };
  res.json = function(payload: any) { this.payload = payload; return this; };
  return res;
}

export async function testOrganizationListFiltered() {
  const controller = new OrganizationController(new FakeOrgServiceList() as any);

  // admin gets all
  {
    const req: any = { user: { role: 'admin', organizationId: 99 }, orgScope: { allowedOrgIds: null } };
    const res = makeRes();
    await controller.list(req as any, res as any);
    if (!Array.isArray(res.payload) || res.payload.length !== 3) throw new Error('admin should receive all orgs');
  }

  // gestor filtered by allowed
  {
    const req: any = { user: { role: 'gestor', organizationId: 99 }, orgScope: { allowedOrgIds: [2,3] } };
    const res = makeRes();
    await controller.list(req as any, res as any);
    const ids = res.payload.map((o: any) => o.id).sort();
    if (ids.join(',') !== '2,3') throw new Error('gestor should get only allowed orgs');
  }

  // cliente with base org fallback
  {
    const req: any = { user: { role: 'cliente', organizationId: 1 }, orgScope: { allowedOrgIds: undefined } };
    const res = makeRes();
    await controller.list(req as any, res as any);
    const ids = res.payload.map((o: any) => o.id);
    if (ids.length !== 1 || ids[0] !== 1) throw new Error('cliente should get only base organization');
  }
}
