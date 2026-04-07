import jwt, { SignOptions } from "jsonwebtoken";
import dotenv from "dotenv";
dotenv.config();

const JWT_SECRET = process.env.JWT_SECRET as string;
// string literal ou número de segundos
const JWT_EXPIRES_IN: SignOptions["expiresIn"] =
  (process.env.JWT_EXPIRES_IN || "7h") as SignOptions["expiresIn"];

export interface JWTPayload {
  id: string;
  role: 'admin' | 'gestor' | 'cliente' | string;
  organizationId: number;
  [key: string]: any;
}

export function signToken(payload: JWTPayload): string {
  const options: SignOptions = { expiresIn: JWT_EXPIRES_IN };
  return jwt.sign(payload, JWT_SECRET, options);
}

export function verifyToken(token: string): JWTPayload {
  try {
    return jwt.verify(token, JWT_SECRET) as JWTPayload;
  } catch {
    throw new Error("Token inválido ou expirado");
  }
}
