import { verifyAccessToken } from '../services/tokenService.js';

export function requireAuth(req, res, next) {
  const header = req.headers.authorization ?? '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) {
    return res.status(401).json({ error: 'UNAUTHORIZED' });
  }
  try {
    req.userId = Number(verifyAccessToken(token).sub);
    next();
  } catch {
    res.status(401).json({ error: 'INVALID_OR_EXPIRED_TOKEN' });
  }
}