import { testTokenService } from './token.service.test';
import { testRateLimit } from './rate-limit.test';
import { testMailServiceFallback } from './mail.service.test';
import { testOrgScopedUnit } from './org-scope.middleware.test';
import { testResolveOrgScopeUnit } from './org-scope.resolve.test';
import { testOrganizationSwitchController } from './organization.controller.switch.test';
import { testOrganizationListFiltered } from './organization.controller.list.test';
import { testSmoke_PersonalData_UsesCurrentOrg, testSmoke_Areas_ListByOrganization_EnforcesCurrentOrg, testSmoke_Processos_List_UsesCurrentOrg } from './smoke.current-org.test';
import { testAuth_MagicLink_Flow } from './auth.controller.magic-link.test';
import { testAuth_InviteAndVerify_Flows } from './auth.controller.invite-verify.test';

async function main() {
  process.env.NODE_ENV = process.env.NODE_ENV || 'test';
  const results: { name: string; ok: boolean; error?: any }[] = [];
  async function run(name: string, fn: () => Promise<void>) {
    try { await fn(); results.push({ name, ok: true }); }
    catch (err) { results.push({ name, ok: false, error: err }); }
  }
  await run('TokenService', testTokenService);
  await run('RateLimit', testRateLimit);
  await run('MailServiceFallback', testMailServiceFallback);
  await run('OrgScopedUnit', testOrgScopedUnit);
  await run('ResolveOrgScopeUnit', testResolveOrgScopeUnit);
  await run('OrganizationSwitchController', testOrganizationSwitchController);
  await run('OrganizationListFiltered', testOrganizationListFiltered);
  await run('Smoke: PersonalData uses current org', testSmoke_PersonalData_UsesCurrentOrg);
  await run('Smoke: Areas listByOrganization enforces current org', testSmoke_Areas_ListByOrganization_EnforcesCurrentOrg);
  await run('Smoke: Processos list uses current org', testSmoke_Processos_List_UsesCurrentOrg);
  await run('Auth: Magic Link Flow', testAuth_MagicLink_Flow);
  await run('Auth: Invite & Verify Flows', testAuth_InviteAndVerify_Flows);
  const ok = results.every(r => r.ok);
  for (const r of results) {
    console.log(`${r.ok ? 'PASS' : 'FAIL'} - ${r.name}${r.ok ? '' : ' - ' + (r.error?.message || r.error)}`);
  }
  process.exit(ok ? 0 : 1);
}

main();
