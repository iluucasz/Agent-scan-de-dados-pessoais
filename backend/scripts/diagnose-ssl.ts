import tls from 'tls';
import net from 'net';
import { once } from 'events';
import crypto from 'crypto';

/*
  Diagnose SSL chain for the configured DATABASE_URL host:port.
  Usage (env): DATABASE_URL=postgres://user:pass@host:port/db node dist/scripts/diagnose-ssl.js
  (Run `npm run build` first.)
*/

function parseDbUrl(raw?: string) {
  if (!raw) throw new Error('DATABASE_URL ausente');
  // Remove query to avoid parsing issues
  const u = new URL(raw);
  return { host: u.hostname, port: +(u.port || '5432') };
}

async function fetchCertificates(host: string, port: number) {
  return new Promise<{ peer: tls.DetailedPeerCertificate; rawChain: tls.DetailedPeerCertificate[] }>((resolve, reject) => {
    const socket = tls.connect({ host, port, servername: host, rejectUnauthorized: false }, () => {
      const peer = socket.getPeerCertificate(true) as tls.DetailedPeerCertificate;
      // Walk chain manually
      const chain: tls.DetailedPeerCertificate[] = [];
      let current: any = peer;
      const seen = new Set<string>();
      while (current && current.raw) {
        const fp = crypto.createHash('sha256').update(current.raw).digest('hex');
        if (seen.has(fp)) break;
        seen.add(fp);
        chain.push(current);
        if (!current.issuerCertificate || current.issuerCertificate === current) break;
        current = current.issuerCertificate;
      }
      resolve({ peer, rawChain: chain });
      socket.end();
    });
    socket.on('error', reject);
  });
}

function formatCertInfo(c: tls.DetailedPeerCertificate, index: number) {
  const sha256 = crypto.createHash('sha256').update(c.raw!).digest('hex');
  return {
    index,
    subject: c.subject, issuer: c.issuer,
    selfSigned: c.subject.CN === c.issuer.CN,
    valid_from: c.valid_from,
    valid_to: c.valid_to,
    sha256,
  };
}

function toPem(raw: Buffer): string {
  const b64 = raw.toString('base64');
  const lines = b64.match(/.{1,64}/g) || [];
  return '-----BEGIN CERTIFICATE-----\n' + lines.join('\n') + '\n-----END CERTIFICATE-----';
}

(async () => {
  try {
    const { host, port } = parseDbUrl(process.env.DATABASE_URL);
    console.log('[diagnose-ssl:start]', { host, port });
    const { rawChain } = await fetchCertificates(host, port);
    const info = rawChain.map(formatCertInfo);
    console.log('[diagnose-ssl:chain]', info);
    const selfSignedRoots = info.filter(i => i.selfSigned);
    // Leaf
    if (rawChain[0]?.raw) {
      console.log('[diagnose-ssl:leaf-fingerprint]', info[0].sha256);
      console.log('[diagnose-ssl:leaf-pem]\n' + toPem(rawChain[0].raw));
    }
    if (selfSignedRoots.length === 0) {
      console.log('[diagnose-ssl:analysis] Nenhum root self-signed detectado explicitamente na cadeia retornada (pode ser root público).');
    } else {
      console.log('[diagnose-ssl:analysis] Roots self-signed na cadeia (possíveis CA a inserir em CA_CERT para modo strict):', selfSignedRoots.map(r => r.sha256));
      // Emitir PEM do primeiro root self-signed
      const rootIdx = selfSignedRoots[0].index;
      const rootCert = rawChain[rootIdx];
      if (rootCert && rootCert.raw) {
        console.log('[diagnose-ssl:root-pem]\n' + toPem(rootCert.raw));
        if (rawChain[0]?.raw && rootIdx !== 0) {
          const bundle = toPem(rawChain[0].raw) + '\n' + toPem(rootCert.raw);
            console.log('[diagnose-ssl:suggest-ca-bundle]\n' + bundle);
        }
      }
    }
    if (process.env.CA_CERT) {
      const b64 = process.env.CA_CERT.replace(/-----BEGIN CERTIFICATE-----/g,'').replace(/-----END CERTIFICATE-----/g,'').replace(/\s+/g,'');
      const der = Buffer.from(b64,'base64');
      const fp = crypto.createHash('sha256').update(der).digest('hex');
      console.log('[diagnose-ssl:env-ca-fingerprint]', fp);
      const match = info.find(i => i.sha256 === fp);
      console.log('[diagnose-ssl:env-ca-match]', !!match);
    }
  } catch (e) {
    console.error('[diagnose-ssl:error]', (e as Error).message);
    process.exit(1);
  }
})();
