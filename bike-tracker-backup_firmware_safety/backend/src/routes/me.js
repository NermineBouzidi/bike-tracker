import { Router } from 'express';
import { hash, verify } from '@node-rs/argon2';
import { z } from 'zod';
import { pool } from '../db.js';
import { requireAuth } from '../../middleware/requireAuth.js';
import { revokeAllForUser } from '../../services/tokenService.js';

export const meRouter = Router();
meRouter.use(requireAuth);

const HASH_OPTIONS = { memoryCost: 19456, timeCost: 2, parallelism: 1 };

meRouter.get('/', async (req, res) => {
  const [rows] = await pool.execute(
    'SELECT id, email, display_name, created_at FROM users WHERE id = ?', [req.userId]);
  if (!rows[0]) return res.status(404).json({ error: 'NOT_FOUND' });
  const u = rows[0];
  res.json({ id: u.id, email: u.email, displayName: u.display_name, createdAt: u.created_at });
});

meRouter.post('/change-password', async (req, res) => {
  const data = z.object({
    currentPassword: z.string().min(1).max(128),
    newPassword: z.string().min(8).max(128),
  }).parse(req.body);

  const [rows] = await pool.execute('SELECT password_hash FROM users WHERE id = ?', [req.userId]);
  if (!rows[0] || !(await verify(rows[0].password_hash, data.currentPassword))) {
    return res.status(401).json({ error: 'INVALID_CREDENTIALS', message: 'Current password is incorrect.' });
  }
  await pool.execute('UPDATE users SET password_hash = ? WHERE id = ?',
    [await hash(data.newPassword, HASH_OPTIONS), req.userId]);
  await revokeAllForUser(req.userId);
  res.json({ message: 'Password changed. Please sign in again.' });
});

// Deletes the account and, through ON DELETE CASCADE, all its trips and tokens
meRouter.delete('/', async (req, res) => {
  const data = z.object({ password: z.string().min(1).max(128) }).parse(req.body);
  const [rows] = await pool.execute('SELECT password_hash FROM users WHERE id = ?', [req.userId]);
  if (!rows[0] || !(await verify(rows[0].password_hash, data.password))) {
    return res.status(401).json({ error: 'INVALID_CREDENTIALS', message: 'Password is incorrect.' });
  }
  await pool.execute('DELETE FROM users WHERE id = ?', [req.userId]);
  res.json({ message: 'Account deleted.' });
});