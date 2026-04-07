import crypto from "crypto";
import { db } from "../db";
import { agentTokens } from "../../schemas/agent.schema";
import { eq } from "drizzle-orm";
import { TelemetryService } from "./telemetry.service";

const sha256b64 = (s: string) => crypto.createHash("sha256").update(s).digest("base64");

export class AgentService {
  private telemetry = new TelemetryService();

  private generateRawToken(bytes = 32) {
    return crypto.randomBytes(bytes).toString("hex");
  }

  private hashToken(raw: string) {
    return sha256b64(raw);
  }

  async generateAgentToken(userId: string): Promise<string> {
    const raw = this.generateRawToken(32);
    const tokenHash = this.hashToken(raw);

    await db.insert(agentTokens).values({
      userId,
      tokenHash,
      isActive: true,
    });

    this.telemetry.track("token.issued", { userId, purpose: 'AGENT_PERMANENT' });
    return raw;
  }

  async resetAgentToken(userId: string): Promise<string> {
    // Invalida todos os tokens anteriores do agent
    await db
      .update(agentTokens)
      .set({ isActive: false, resetAt: new Date() })
      .where(eq(agentTokens.userId, userId));

    const raw = this.generateRawToken(32);
    const tokenHash = this.hashToken(raw);

    await db.insert(agentTokens).values({
      userId,
      tokenHash,
      isActive: true,
    });

    this.telemetry.track("token.issued", { userId, purpose: 'AGENT_RESET' });
    return raw;
  }

  async validateAgentToken(raw: string): Promise<{ userId: string } | null> {
    const tokenHash = this.hashToken(raw);

    const [row] = await db
      .select()
      .from(agentTokens)
      .where(eq(agentTokens.tokenHash, tokenHash));

    if (!row || row.isActive === false) {
      this.telemetry.track("token.consumed", { error: 'invalid_agent_token' });
      return null;
    }

    return { userId: row.userId };
  }

  async markTokenUsed(raw: string): Promise<void> {
    const tokenHash = this.hashToken(raw);

    await db
      .update(agentTokens)
      .set({ lastUsedAt: new Date() })
      .where(eq(agentTokens.tokenHash, tokenHash));
  }
}
