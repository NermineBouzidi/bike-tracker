import nodemailer from 'nodemailer';
import { config } from '../src/config.js';

const transporter = nodemailer.createTransport({
  host: config.smtp.host,
  port: config.smtp.port,
  secure: false,
  auth: { user: config.smtp.user, pass: config.smtp.password },
});

export async function sendCodeEmail(to, code, purpose) {
  const isReset = purpose === 'reset';
  const title = isReset ? 'Reset your password' : 'Verify your email';
  const intro = isReset
    ? 'Use this code to choose a new password.'
    : 'Thank you for creating an account.';

  await transporter.sendMail({
    from: `"Bike Tracker" <${config.smtp.from}>`,
    to,
    subject: `Bike Tracker - ${title}`,
    text: `${intro} Your code is ${code}. It expires in 10 minutes.`,
    html: `
      <div style="font-family: Arial; max-width: 500px; margin: auto;">
        <h2>${title}</h2>
        <p>${intro}</p>
        <h1 style="letter-spacing: 8px; color: #2563eb;">${code}</h1>
        <p>This code expires in 10 minutes. If you did not ask for it, ignore this email.</p>
      </div>`,
  });
}