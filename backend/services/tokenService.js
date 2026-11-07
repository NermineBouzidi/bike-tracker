import crypto from 'node:crypto';
import jwt from 'jsonwebtoken';
import { config } from '../src/config.js';
import { pool } from '../src/db.js';

const sha256 = (v) => crypto.createHash('sha256').update(v).digest('hex');

export function signAccessToken(userId) {
  return jwt.sign({ sub: String(userId) }, config.jwt.secret, {
    algorithm: 'HS256',
    expiresIn: config.jwt.accessTtl,
  });
}

export function verifyAccessToken(token) {
  return jwt.verify(token, config.jwt.secret, { algorithms: ['HS256'] });
}

export async function issueRefreshToken(userId) {
  const token = crypto.randomBytes(32).toString('hex');
  await pool.execute(
    `INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
     VALUES (?, ?, DATE_ADD(UTC_TIMESTAMP(), INTERVAL ${config.jwt.refreshDays} DAY))`,
    [userId, sha256(token)],
  );
  return token;
}

export async function revokeAllForUser(userId) {
  await pool.execute(
    'UPDATE refresh_tokens SET revoked_at = UTC_TIMESTAMP() WHERE user_id = ? AND revoked_at IS NULL',
    [userId],
  );
}

export async function revokeRefreshToken(token) {
  await pool.execute(
    'UPDATE refresh_tokens SET revoked_at = UTC_TIMESTAMP() WHERE token_hash = ? AND revoked_at IS NULL',
    [sha256(token)],
  );
}

// Swaps a refresh token for a new one. A token used twice is treated as stolen.
export async function rotateRefreshToken(token) {
  const [rows] = await pool.execute(
    `SELECT id, user_id, revoked_at, expires_at > UTC_TIMESTAMP() AS still_valid
     FROM refresh_tokens WHERE token_hash = ?`,
    [sha256(token)],
  );
  const row = rows[0];
  if (!row) return null;
  if (row.revoked_at) {
    await revokeAllForUser(row.user_id);
    return null;
  }
  if (!row.still_valid) return null;

  await pool.execute(
    'UPDATE refresh_tokens SET revoked_at = UTC_TIMESTAMP() WHERE id = ?',
    [row.id],
  );
  return { userId: row.user_id, refreshToken: await issueRefreshToken(row.user_id) };
}