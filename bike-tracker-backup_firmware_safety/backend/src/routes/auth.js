import { Router } from 'express';
import { hash, verify } from '@node-rs/argon2';
import { z } from 'zod';
import { pool } from '../db.js';
import { sendCodeEmail } from '../../services/emailService.js';
import { canIssueCode, createCode, consumeCode } from '../../services/codeService.js';
import {
  signAccessToken, issueRefreshToken, rotateRefreshToken, revokeRefreshToken, revokeAllForUser,
} from '../../services/tokenService.js';
import { loginLimiter, emailLimiter, authLimiter } from '../../middleware/rateLimits.js';

export const authRouter = Router();

const HASH_OPTIONS = { memoryCost: 19456, timeCost: 2, parallelism: 1 };
// used when the email is unknown, so the response time looks the same
const DUMMY_HASH = await hash('not-a-real-password', HASH_OPTIONS);

const email = z.string().trim().toLowerCase().max(255).email();
const password = z.string().min(8).max(128);
const code = z.string().regex(/^\d{6}$/);
const refreshToken = z.string().min(32).max(200);

async function sendCode(userId, userEmail, type) {
  const c = await createCode(userId, type);
  await sendCodeEmail(userEmail, c, type);
}

// 1. Register
authRouter.post('/register', emailLimiter, async (req, res) => {
  const data = z.object({
    email, password, displayName: z.string().trim().min(2).max(100),
  }).parse(req.body);

  const passwordHash = await hash(data.password, HASH_OPTIONS);
  let userId;
  try {
    const [result] = await pool.execute(
      'INSERT INTO users (email, password_hash, display_name) VALUES (?, ?, ?)',
      [data.email, passwordHash, data.displayName],
    );
    userId = result.insertId;
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ error: 'EMAIL_TAKEN', message: 'This email is already registered.' });
    }
    throw err;
  }

  let emailSent = true;
  try {
    await sendCode(userId, data.email, 'verify');
  } catch (e) {
    console.error('Verification email failed:', e.message);
    emailSent = false;
  }
  res.status(201).json({
    id: userId, email: data.email, displayName: data.displayName,
    verificationRequired: true, emailSent,
  });
});

// 2. Verify email with the 6-digit code
authRouter.post('/verify-email', authLimiter, async (req, res) => {
  const data = z.object({ email, code }).parse(req.body);
  const fail = () =>
    res.status(400).json({ error: 'INVALID_CODE', message: 'The code is invalid or has expired.' });

  const [users] = await pool.execute(
    'SELECT id, email_verified_at FROM users WHERE email = ?', [data.email]);
  const user = users[0];
  if (!user) return fail();
  if (user.email_verified_at) return res.json({ verified: true });

  if (!(await consumeCode(user.id, 'verify', data.code))) return fail();
  await pool.execute(
    'UPDATE users SET email_verified_at = UTC_TIMESTAMP() WHERE id = ?', [user.id]);
  res.json({ verified: true });
});

// 3. Ask for a new verification code
authRouter.post('/resend-verification', emailLimiter, async (req, res) => {
  const data = z.object({ email }).parse(req.body);
  const [users] = await pool.execute(
    'SELECT id, email, email_verified_at FROM users WHERE email = ?', [data.email]);
  const user = users[0];
  if (user && !user.email_verified_at && (await canIssueCode(user.id, 'verify'))) {
    await sendCode(user.id, user.email, 'verify')
      .catch((e) => console.error('Resend failed:', e.message));
  }
  res.json({ message: 'If the account exists and is not verified, a new code was sent.' });
});

// 4. Login
authRouter.post('/login', loginLimiter, async (req, res) => {
  const data = z.object({ email, password: z.string().min(1).max(128) }).parse(req.body);

  const [rows] = await pool.execute(
    'SELECT id, email, display_name, password_hash, email_verified_at FROM users WHERE email = ?',
    [data.email]);
  const user = rows[0];

  const ok = await verify(user ? user.password_hash : DUMMY_HASH, data.password);
  if (!user || !ok) {
    return res.status(401).json({ error: 'INVALID_CREDENTIALS', message: 'Email or password is incorrect.' });
  }
  if (!user.email_verified_at) {
    return res.status(403).json({ error: 'EMAIL_NOT_VERIFIED', message: 'Please verify your email first.' });
  }

  res.json({
    accessToken: signAccessToken(user.id),
    refreshToken: await issueRefreshToken(user.id),
    user: { id: user.id, email: user.email, displayName: user.display_name },
  });
});

// 5. Get a new access token
authRouter.post('/refresh', authLimiter, async (req, res) => {
  const data = z.object({ refreshToken }).parse(req.body);
  const rotated = await rotateRefreshToken(data.refreshToken);
  if (!rotated) {
    return res.status(401).json({ error: 'INVALID_REFRESH_TOKEN' });
  }
  res.json({
    accessToken: signAccessToken(rotated.userId),
    refreshToken: rotated.refreshToken,
  });
});

// 6. Logout
authRouter.post('/logout', authLimiter, async (req, res) => {
  const data = z.object({ refreshToken }).parse(req.body);
  await revokeRefreshToken(data.refreshToken);
  res.json({ message: 'Logged out.' });
});

// 7. Forgot password: always the same answer
authRouter.post('/forgot-password', emailLimiter, async (req, res) => {
  const data = z.object({ email }).parse(req.body);
  const [users] = await pool.execute(
    'SELECT id, email, email_verified_at FROM users WHERE email = ?', [data.email]);
  const user = users[0];
  if (user && user.email_verified_at && (await canIssueCode(user.id, 'reset'))) {
    await sendCode(user.id, user.email, 'reset')
      .catch((e) => console.error('Reset email failed:', e.message));
  }
  res.json({ message: 'If the account exists, a reset code was sent.' });
});

// 8. Reset password with the code
authRouter.post('/reset-password', authLimiter, async (req, res) => {
  const data = z.object({ email, code, newPassword: password }).parse(req.body);
  const fail = () =>
    res.status(400).json({ error: 'INVALID_CODE', message: 'The code is invalid or has expired.' });

  const [users] = await pool.execute('SELECT id FROM users WHERE email = ?', [data.email]);
  const user = users[0];
  if (!user) return fail();
  if (!(await consumeCode(user.id, 'reset', data.code))) return fail();

  const newHash = await hash(data.newPassword, HASH_OPTIONS);
  await pool.execute('UPDATE users SET password_hash = ? WHERE id = ?', [newHash, user.id]);
  await revokeAllForUser(user.id); // logs out every device
  res.json({ message: 'Password updated. Please sign in.' });
});