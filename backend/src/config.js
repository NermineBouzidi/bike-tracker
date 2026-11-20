import 'dotenv/config';

function required(name, minLength = 1) {
  const value = process.env[name];
  if (!value || value.length < minLength) {
    throw new Error(`Missing or too short environment variable: ${name}`);
  }
  return value;
}

export const config = {
  port: Number(process.env.PORT || 3000),
  db: {
    host: required('DB_HOST'),
    port: Number(process.env.DB_PORT || 3306),
    user: required('DB_USER'),
    password: required('DB_PASSWORD'),
    database: required('DB_NAME'),
  },
  jwt: { secret: required('JWT_SECRET', 32), accessTtl: '15m', refreshDays: 30 },
  emailTokenSecret: required('EMAIL_TOKEN_SECRET', 32),
  smtp: {
    host: 'smtp.gmail.com',
    port: 587,
    user: required('MAIL_USER'),
    password: required('MAIL_PASS'),
    from: required('MAIL_USER'),
  },
};