import { orgScoped } from '../server/middlewares/org-scope.middleware';
import type { Request, Response, NextFunction } from 'express';

export async function testOrgScopedUnit() {
  // helper to simulate req/res/next
  const make = (allowed: number[] | null, value: any) => {
    const req: any = { orgScope: { allowedOrgIds: allowed }, query: { organizationId: value } } as Partial<Request>;
    const res: any = { statusCode: 200, _json: undefined, status(code: number) { this.statusCode = code; return this; }, json(payload: any) { this._json = payload; return this; } } as Partial<Response>;
    let called = false; const next: NextFunction = () => { called = true; };
    return { req: req as Request, res: res as Response, next, called: () => called };
  };

  // admin (allowed=null) always passes
  {
    const { req, res, next, called } = make(null, 123);
    const mw = orgScoped();
    mw(req, res, next);
    if (!called()) throw new Error('admin should pass');
  }

  // allowed list contains org
  {
    const { req, res, next, called } = make([1,2,3], 2);
    const mw = orgScoped();
    mw(req, res, next);
    if (!called()) throw new Error('allowed org should pass');
  }

  // denied org
  {
    const { req, res, next, called } = make([1,2,3], 5);
    const mw = orgScoped();
    mw(req, res, next);
    if (called()) throw new Error('denied org should not pass');
  }

  // invalid value
  {
    const { req, res, next, called } = make([1], 'abc');
    const mw = orgScoped();
    mw(req, res, next);
    if (called()) throw new Error('invalid orgId should 400');
  }
}
