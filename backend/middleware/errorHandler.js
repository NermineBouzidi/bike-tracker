import { ZodError } from 'zod';

export function errorHandler(err, _req, res, _next) {
  if (err instanceof ZodError) {
    return res.status(400).json({
      error: 'VALIDATION',
      issues: err.issues.map((i) => ({ field: i.path.join('.'), message: i.message })),
    });
  }
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({ error: 'BAD_JSON' });
  }
  console.error(err);
  res.status(500).json({ error: 'INTERNAL' });
}