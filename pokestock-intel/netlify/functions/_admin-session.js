import { createHmac, timingSafeEqual } from "node:crypto";

const tokenTtlMs = 12 * 60 * 60 * 1000;

const base64url = (value) => Buffer.from(value).toString("base64url");
const unbase64url = (value) => Buffer.from(value, "base64url").toString("utf8");
const secret = () => process.env.ADMIN_SESSION_SECRET || process.env.ADMIN_PASSWORD || "ilovepokemon!";
const sign = (payload) => createHmac("sha256", secret()).update(payload).digest("base64url");

const constantEqual = (left, right) => {
  const leftBuffer = Buffer.from(String(left));
  const rightBuffer = Buffer.from(String(right));
  return leftBuffer.length === rightBuffer.length && timingSafeEqual(leftBuffer, rightBuffer);
};

export const response = (statusCode, body) => ({
  statusCode,
  headers: { "content-type": "application/json" },
  body: JSON.stringify(body),
});

export const validateCredentials = (username, password) => {
  const expectedUsername = process.env.ADMIN_USERNAME || "admin";
  const expectedPassword = process.env.ADMIN_PASSWORD || "ilovepokemon!";
  return constantEqual(username, expectedUsername) && constantEqual(password, expectedPassword);
};

export const createAdminToken = () => {
  const payload = base64url(JSON.stringify({ sub: "admin", exp: Date.now() + tokenTtlMs }));
  return `${payload}.${sign(payload)}`;
};

export const verifyAdminToken = (token) => {
  if (!token || !token.includes(".")) return false;
  const [payload, signature] = token.split(".");
  if (!constantEqual(signature, sign(payload))) return false;

  try {
    const decoded = JSON.parse(unbase64url(payload));
    return decoded.sub === "admin" && Number(decoded.exp) > Date.now();
  } catch {
    return false;
  }
};

export const requireAdmin = (event) => {
  const header = event.headers.authorization || event.headers.Authorization || "";
  const token = header.startsWith("Bearer ") ? header.slice("Bearer ".length) : "";
  return verifyAdminToken(token);
};
