import { existsSync } from 'node:fs';

if (existsSync('.env')) process.loadEnvFile('.env');

function bool(v: string | undefined, fallback: boolean): boolean {
  return v === undefined ? fallback : v === 'true' || v === '1';
}

export interface AppConfig {
  port: number;
  databaseUrl: string;
  jwtSecret: string;
  smsProvider: 'console';
  otpDevBypass: boolean;
  moderationProvider: 'auto' | 'manual';
  verificationProvider: 'auto' | 'manual';
  mediaDir: string;
  publicBaseUrl: string;
  adminToken: string;
  freeDailyLikes: number;
  /** Days a skipped profile stays out of discovery before it can return (DI-3). */
  skipCooldownDays: number;
  /** Timezone the daily like limit resets in. */
  likeResetTimezone: string;
}

export function loadConfig(overrides: Partial<AppConfig> = {}): AppConfig {
  const env = process.env;
  const isProd = env.NODE_ENV === 'production';
  const config: AppConfig = {
    port: Number(env.PORT ?? 3000),
    databaseUrl: env.DATABASE_URL ?? 'file://./.data/pglite',
    jwtSecret: env.JWT_SECRET ?? 'dev-secret',
    smsProvider: 'console',
    otpDevBypass: bool(env.OTP_DEV_BYPASS, !isProd),
    moderationProvider: (env.MODERATION_PROVIDER as AppConfig['moderationProvider']) ?? 'auto',
    verificationProvider: (env.VERIFICATION_PROVIDER as AppConfig['verificationProvider']) ?? 'auto',
    mediaDir: env.MEDIA_DIR ?? './.data/media',
    publicBaseUrl: env.PUBLIC_BASE_URL ?? `http://localhost:${env.PORT ?? 3000}`,
    adminToken: env.ADMIN_TOKEN ?? 'dev-admin',
    freeDailyLikes: Number(env.FREE_DAILY_LIKES ?? 8),
    skipCooldownDays: 30,
    likeResetTimezone: 'Asia/Kolkata',
    ...overrides,
  };
  if (isProd) {
    if (config.jwtSecret === 'dev-secret') throw new Error('JWT_SECRET must be set in production');
    if (config.otpDevBypass) throw new Error('OTP_DEV_BYPASS must be off in production');
    if (config.moderationProvider === 'auto') throw new Error('Auto-approve moderation is dev only');
  }
  return config;
}

export const APP_CONFIG = Symbol('APP_CONFIG');
