import express from 'express';
import helmet from 'helmet';
import { pool } from './db.js';
import { authRouter } from './routes/auth.js';
import { meRouter } from './routes/me.js';
import { errorHandler } from '../middleware/errorHandler.js';

export const app = express();

app.disable('x-powered-by');
app.use(helmet());
app.use(express.json({ limit: '100kb' }));

app.get('/health', async (_req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ok', db: 'up' });
  } catch (err) {
    console.error('Health check failed:', err.message);
    res.status(503).json({ status: 'error', db: 'down' });
  }
});

app.use('/auth', authRouter);
app.use('/me', meRouter);
app.use((_req, res) => res.status(404).json({ error: 'NOT_FOUND' }));
app.use(errorHandler);