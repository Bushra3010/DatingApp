import { Injectable, NotImplementedException } from '@nestjs/common';
import { Db } from '../db/db.service';

/** Plus plans from PRD section 7. Prices are display hints; stores charge in the local currency. */
export const PLANS = [
  { productId: 'kindred_plus_1m', tier: 'plus', months: 1, priceInr: 499 },
  { productId: 'kindred_plus_3m', tier: 'plus', months: 3, priceInr: 1199 },
] as const;

export type Store = 'play' | 'app_store' | 'dev';

@Injectable()
export class BillingService {
  constructor(private readonly db: Db) {}

  plans() {
    return PLANS;
  }

  /**
   * Verifies a store purchase and grants the entitlement. Only the "dev" store works today; Google Play
   * Billing and App Store server verification (plus their renewal webhooks) are the next step.
   */
  async verify(userId: string, store: Store, productId: string, purchaseToken: string) {
    const plan = PLANS.find((p) => p.productId === productId);
    if (!plan) throw new NotImplementedException('Unknown product');
    if (store === 'dev' && process.env.NODE_ENV === 'production') throw new NotImplementedException('Dev purchases are disabled');
    if (store !== 'dev') throw new NotImplementedException(`${store} receipt verification is not wired up yet`);
    const row = await this.db.one(
      `WITH sub AS (
         INSERT INTO subscriptions (user_id, store, product_id, external_id, expires_at)
         VALUES ($1, $2, $3, $4, now() + make_interval(months => $5))
         ON CONFLICT (store, external_id) DO UPDATE SET external_id = EXCLUDED.external_id
         RETURNING user_id, expires_at
       )
       UPDATE users u SET plan = 'plus', plan_expires_at = sub.expires_at FROM sub
       WHERE u.id = sub.user_id AND sub.user_id = $1 RETURNING u.plan, u.plan_expires_at`,
      [userId, store, productId, purchaseToken, plan.months],
    );
    if (!row) throw new NotImplementedException('Purchase belongs to another account');
    return { plan: row.plan, expiresAt: row.plan_expires_at };
  }
}
