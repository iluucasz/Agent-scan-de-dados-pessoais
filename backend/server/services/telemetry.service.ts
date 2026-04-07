type TelemetryEvent =
  | 'token.issued'
  | 'token.consumed'
  | 'mail.sent'
  | 'mail.error';

export class TelemetryService {
  track(event: TelemetryEvent, data: Record<string, unknown> = {}) {
    try {
      const payload = { ts: new Date().toISOString(), event, ...data };
      // For now, log to console; can be replaced with a proper sink later
      console.log('[telemetry]', JSON.stringify(payload));
    } catch {}
  }
}
