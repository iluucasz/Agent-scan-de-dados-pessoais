import { Request, Response, NextFunction } from 'express';

type Key = string;
type Entry = { count: number; resetAt: number };

const store = new Map<Key, Entry>();

function nowSec() { return Math.floor(Date.now() / 1000); }

export function rateLimit(options?: { windowSec?: number; max?: number; keyFn?: (req: Request) => string }) {
  const windowSec = options?.windowSec ?? Number(process.env.RATE_LIMIT_WINDOW || 60);
  const max = options?.max ?? Number(process.env.RATE_LIMIT_MAX || 10);
  const keyFn = options?.keyFn ?? ((req: Request) => {
    const ip = req.ip || 'unknown';
    const email = (req.body && typeof req.body.email === 'string') ? req.body.email.toLowerCase() : '';
    return `${ip}:${email}`;
  });

  return (req: Request, res: Response, next: NextFunction) => {
    try {
      const key = keyFn(req);
      const ts = nowSec();
      const entry = store.get(key);
      if (!entry || entry.resetAt <= ts) {
        store.set(key, { count: 1, resetAt: ts + windowSec });
        return next();
      }
      if (entry.count < max) {
        entry.count += 1;
        return next();
      }
      const retryAfter = Math.max(0, entry.resetAt - ts);
      res.setHeader('Retry-After', String(retryAfter));
      return res.status(429).json({ message: 'Limite de tentativas excedido. Tente novamente em instantes.' });
    } catch (err) {
      return next(err);
    }
  };
}
