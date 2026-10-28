// AES-GCM encryption for Whoop tokens at rest. The key lives only in the edge function
// secrets (TOKEN_ENCRYPTION_KEY, 32 random bytes, base64), never in the database.

import { base64ToBytes, bytesToBase64 } from "./whoop.ts";

const VERSION = "v1";

async function importKey(base64Key: string): Promise<CryptoKey> {
  const raw = base64ToBytes(base64Key);
  if (raw.length !== 32) throw new Error("TOKEN_ENCRYPTION_KEY must be 32 bytes (base64)");
  return crypto.subtle.importKey("raw", raw, "AES-GCM", false, ["encrypt", "decrypt"]);
}

/** Returns "v1.<iv>.<ciphertext>" in base64. */
export async function encryptToken(plaintext: string, base64Key: string): Promise<string> {
  const key = await importKey(base64Key);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const sealed = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, new TextEncoder().encode(plaintext));
  return [VERSION, bytesToBase64(iv), bytesToBase64(new Uint8Array(sealed))].join(".");
}

export async function decryptToken(sealed: string, base64Key: string): Promise<string> {
  const [version, iv, data] = sealed.split(".");
  if (version !== VERSION || !iv || !data) throw new Error("Unrecognised token format");
  const key = await importKey(base64Key);
  const plain = await crypto.subtle.decrypt({ name: "AES-GCM", iv: base64ToBytes(iv) }, key, base64ToBytes(data));
  return new TextDecoder().decode(plain);
}
