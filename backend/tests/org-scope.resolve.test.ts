import { resolveOrgScope } from '../server/middlewares/org-scope.middleware';
import { db } from '../server/db';
import type { Request, Response, NextFunction } from 'express';

function makeReq(user: any): Request {
  return { user } as unknown as Request;
}

function makeRes() {
  const res: any = { statusCode: 200, body: undefined } as Partial<Response>;
  res.status = function(code: number) { this.statusCode = code; return this; };
  res.json = function(payload: any) { this.body = payload; return this; };
  return res as Response;
}

export async function testResolveOrgScopeUnit() {
  const originalSelect = (db as any).select;
  try {
    // admin → allowedOrgIds = null
    {
      const req = makeReq({ id: 'u1', role: 'admin', organizationId: 1 });
      const res = makeRes();
      let called = false; const next: NextFunction = () => { called = true; };
      await resolveOrgScope(req, res, next);
      if (!called) throw new Error('next not called for admin');
      if (req.orgScope?.allowedOrgIds !== null) throw new Error('admin should have allowedOrgIds=null');
    }

    // gestor → managed orgs from DB; sets current if missing
    {
      (db as any).select = () => ({
        from: () => ({
          where: async () => ([{ organizationId: 10 }, { organizationId: 20 }])
        })
      });
      const req = makeReq({ id: 'u2', role: 'gestor' });
      const res = makeRes();
      let called = false; const next: NextFunction = () => { called = true; };
      await resolveOrgScope(req, res, next);
      if (!called) throw new Error('next not called for gestor');
      const scope = req.orgScope!;
      if (!scope.managedOrganizationIds || scope.managedOrganizationIds.length !== 2) throw new Error('gestor managed orgs not derived');
      if (!scope.currentOrganizationId || scope.currentOrganizationId !== 10) throw new Error('gestor currentOrganizationId fallback not set');
      if (!scope.allowedOrgIds || scope.allowedOrgIds.length !== 2) throw new Error('gestor allowedOrgIds incorrect');
    }

    // cliente → allowed only currentOrganizationId
    {
      const req = makeReq({ id: 'u3', role: 'cliente', currentOrganizationId: 7, organizationId: 99 });
      const res = makeRes();
      let called = false; const next: NextFunction = () => { called = true; };
      await resolveOrgScope(req, res, next);
      if (!called) throw new Error('next not called for cliente');
      const scope = req.orgScope!;
      if (!scope.allowedOrgIds || scope.allowedOrgIds[0] !== 7 || scope.allowedOrgIds.length !== 1) {
        throw new Error('cliente allowedOrgIds should be [currentOrganizationId]');
      }
    }
  } finally {
    (db as any).select = originalSelect;
  }
}
