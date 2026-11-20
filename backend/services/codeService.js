import crypto from 'node:crypto';
import { config } from '../src/config.js';
import { pool } from '../src/db.js';

const TTL_MINUTES = 10;
const MAX_ATTEMPTS = 5;
const RESEND_SECONDS = 60;

const hashCode = (code) =>
  crypto.createHmac('sha256', config.emailTokenSecret).update(code).digest('hex');

// false if a code was already sent less than a minute ago
export async function canIssueCode(userId, type) {
  const [rows] = await pool.execute(
    `SELECT id FROM email_tokens
     WHERE user_id = ? AND type = ?
       AND created_at > DATE_SUB(UTC_TIMESTAMP(), INTERVAL ${RESEND_SECONDS} SECOND)
     LIMIT 1`,
    [userId, type],
  );
  return rows.length === 0;
}

export async function createCode(userId, type) {
  const code = crypto.randomInt(100000, 1000000).toString();
  await pool.execute(
    'UPDATE email_tokens SET used_at = UTC_TIMESTAMP() WHERE user_id = ? AND type = ? AND used_at IS NULL',
    [userId, type],
  );
  await pool.execute(
    `INSERT INTO email_tokens (user_id, type, token_hash, expires_at, created_at)
     VALUES (?, ?, ?, DATE_ADD(UTC_TIMESTAMP(), INTERVAL ${TTL_MINUTES} MINUTE), UTC_TIMESTAMP())`,
    [userId, type, hashCode(code)],
  );
  return code;
}

// true only for the right, unexpired code, within 5 attempts
export async function consumeCode(userId, type, code) {
  const [rows] = await pool.execute(
    `SELECT id, token_hash, attempts FROM email_tokens
     WHERE user_id = ? AND type = ? AND used_at IS NULL AND expires_at > UTC_TIMESTAMP()
     ORDER BY id DESC LIMIT 1`,
    [userId, type],
  );
  const row = rows[0];
  if (!row || row.attempts >= MAX_ATTEMPTS) return false;

  const ok = crypto.timingSafeEqual(
    Buffer.from(hashCode(code)),
    Buffer.from(row.token_hash),
  );
  if (!ok) {
    await pool.execute('UPDATE email_tokens SET attempts = attempts + 1 WHERE id = ?', [row.id]);
    return false;
  }
  await pool.execute('UPDATE email_tokens SET used_at = UTC_TIMESTAMP() WHERE id = ?', [row.id]);
  return true;
}