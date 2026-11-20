import rateLimit from 'express-rate-limit';

const make = (limit, minutes) =>
  rateLimit({
    windowMs: minutes * 60 * 1000,
    limit,
    standardHeaders: true,
    legacyHeaders: false,
    message: { error: 'TOO_MANY_REQUESTS', message: 'Too many attempts. Try again later.' },
  });

export const loginLimiter = make(10, 15);
export const emailLimiter = make(5, 15);
export const authLimiter = make(30, 15);