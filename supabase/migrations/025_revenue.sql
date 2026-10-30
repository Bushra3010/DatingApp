-- Revenue: plan prices per country, promo codes, in-app purchase items and
-- a ledger of payments, with admin tools and reports.
--
-- Money only enters the ledger through record_payment(), which is for the
-- server (a payment provider's webhook, using the service role) or an
-- admin recording a manual payment. Members can't write payments. Until a
-- payment provider (e.g. Razorpay, Google Play, App Store) is connected,
-- the ledger stays empty and the reports show zero.

create table if not exists public.plan_prices (
  country text not null,                    -- e.g. 'India'
  currency text not null default 'INR',
  symbol text not null default '₹',
  plan text not null check (plan in ('plus', 'gold', 'platinum')),
  price numeric(10, 2) not null check (price >= 0),
  active boolean not null default true,
  updated_at timestamptz not null default now(),
  primary key (country, plan)
);

insert into public.plan_prices (country, currency, symbol, plan, price) values
  ('India', 'INR', '₹', 'plus', 249),
  ('India', 'INR', '₹', 'gold', 499),
  ('India', 'INR', '₹', 'platinum', 899)
on conflict do nothing;

create table if not exists public.promo_codes (
  code text primary key check (code ~ '^[A-Z0-9_-]{3,24}$'),
  kind text not null check (kind in ('percent', 'amount', 'trial_days')),
  value numeric(10, 2) not null check (value > 0),
  plans text[] not null default '{}',       -- empty: every plan
  max_uses int,                              -- null: unlimited
  uses int not null default 0,
  expires_at timestamptz,
  active boolean not null default true,
  note text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.iap_products (
  id text primary key check (id ~ '^[a-z0-9_]{2,40}$'),
  name text not null,
  price numeric(10, 2) not null check (price >= 0),
  currency text not null default 'INR',
  active boolean not null default true,
  updated_at timestamptz not null default now()
);

insert into public.iap_products (id, name, price) values
  ('boost_1', 'Boost (30 min)', 99),
  ('sparks_5', 'Sparks x5', 149)
on conflict do nothing;

create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles (id) on delete set null,
  kind text not null check (kind in ('subscription', 'iap')),
  item text not null,                        -- plan ('gold') or product id ('boost_1')
  amount numeric(10, 2) not null check (amount >= 0),
  currency text not null default 'INR',
  store text not null check (store in ('razorpay', 'google', 'apple', 'stripe', 'manual')),
  status text not null default 'paid' check (status in ('paid', 'pending', 'failed', 'refunded')),
  provider_ref text unique,                  -- the provider's payment id
  promo_code text,
  country text not null default 'India',
  note text not null default '',
  created_at timestamptz not null default now(),
  refunded_at timestamptz
);
create index if not exists transactions_created on public.transactions (created_at desc);
create index if not exists transactions_user on public.transactions (user_id);

alter table public.plan_prices enable row level security;
alter table public.promo_codes enable row level security;
alter table public.iap_products enable row level security;
alter table public.transactions enable row level security;
revoke all on public.plan_prices, public.promo_codes, public.iap_products, public.transactions
  from anon, authenticated;
-- The app reads active prices and products directly.
grant select on public.plan_prices, public.iap_products to anon, authenticated;
drop policy if exists "active prices" on public.plan_prices;
create policy "active prices" on public.plan_prices for select using (active);
drop policy if exists "active products" on public.iap_products;
create policy "active products" on public.iap_products for select using (active);

-- What a promo code takes off a plan, for the membership screen.
create or replace function public.check_promo(promo text, plan text)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce((
    select jsonb_build_object('valid', true, 'kind', p.kind, 'value', p.value)
      from public.promo_codes p
     where p.code = upper(trim(promo)) and p.active
       and (p.expires_at is null or p.expires_at > now())
       and (p.max_uses is null or p.uses < p.max_uses)
       and (cardinality(p.plans) = 0 or plan = any (p.plans))),
    jsonb_build_object('valid', false))
$$;
revoke all on function public.check_promo(text, text) from public, anon;
grant execute on function public.check_promo(text, text) to authenticated;

-- Records a payment. A paid subscription gives the member that plan for
-- a month (from now, or from the end of their current paid month).
-- Not granted to members: a provider webhook calls it with the service
-- role, and admins use admin_record_payment() below.
create or replace function public.record_payment(
  p_member uuid, p_kind text, p_item text, p_amount numeric, p_currency text, p_store text,
  p_status text default 'paid', p_ref text default null, p_promo text default null,
  p_country text default 'India', p_note text default '')
returns uuid language plpgsql security definer set search_path = public as $$
declare
  made uuid;
begin
  insert into public.transactions (user_id, kind, item, amount, currency, store, status,
                                   provider_ref, promo_code, country, note)
  values (p_member, p_kind, p_item, p_amount, p_currency, p_store, p_status,
          p_ref, nullif(upper(trim(p_promo)), ''), p_country, p_note)
  on conflict (provider_ref) do nothing
  returning id into made;
  if made is null then return null; end if;  -- the same payment twice
  if p_status = 'paid' and p_promo is not null then
    update public.promo_codes set uses = uses + 1 where code = upper(trim(p_promo));
  end if;
  if p_status = 'paid' and p_kind = 'subscription' and p_member is not null then
    update public.profiles
       set plan = p_item,
           plan_until = greatest(coalesce(plan_until, now()), now()) + interval '1 month'
     where id = p_member;
  end if;
  return made;
end $$;
revoke all on function public.record_payment(uuid, text, text, numeric, text, text, text, text, text, text, text)
  from public, anon, authenticated;

-- A member's own payments, for a receipts list.
create or replace function public.my_transactions()
returns table (id uuid, kind text, item text, amount numeric, currency text, status text, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select t.id, t.kind, t.item, t.amount, t.currency, t.status, t.created_at
    from public.transactions t where t.user_id = auth.uid() order by t.created_at desc
$$;
revoke all on function public.my_transactions() from public, anon;
grant execute on function public.my_transactions() to authenticated;

-- ---------------------------------------------------------------------------
-- Admin (permission 'billing').
-- ---------------------------------------------------------------------------
create or replace function public.admin_billing_config()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public.require_admin('billing');
  return jsonb_build_object(
    'prices', (select coalesce(jsonb_agg(to_jsonb(p) order by p.country, p.price), '[]') from public.plan_prices p),
    'promos', (select coalesce(jsonb_agg(to_jsonb(p) order by p.created_at desc), '[]') from public.promo_codes p),
    'products', (select coalesce(jsonb_agg(to_jsonb(p) order by p.price), '[]') from public.iap_products p));
end $$;

-- rows: [{country, currency, symbol, plan, price, active}]
create or replace function public.admin_save_prices(rows jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare
  r jsonb;
begin
  perform public.require_admin('billing');
  for r in select * from jsonb_array_elements(rows) loop
    insert into public.plan_prices (country, currency, symbol, plan, price, active)
    values (trim(r->>'country'), upper(trim(r->>'currency')), r->>'symbol', r->>'plan',
            (r->>'price')::numeric, coalesce((r->>'active')::boolean, true))
    on conflict (country, plan) do update
      set currency = excluded.currency, symbol = excluded.symbol, price = excluded.price,
          active = excluded.active, updated_at = now();
  end loop;
  perform public.log_admin('billing_prices', null, jsonb_build_object('rows', jsonb_array_length(rows)));
end $$;

create or replace function public.admin_delete_price(p_country text, p_plan text)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin('billing');
  delete from public.plan_prices where country = p_country and plan = p_plan;
  perform public.log_admin('billing_price_delete', null, jsonb_build_object('country', p_country, 'plan', p_plan));
end $$;

-- row: {code, kind, value, plans, max_uses, expires_at, active, note}
create or replace function public.admin_save_promo(item jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin('billing');
  insert into public.promo_codes (code, kind, value, plans, max_uses, expires_at, active, note)
  values (upper(trim(item->>'code')), item->>'kind', (item->>'value')::numeric,
          coalesce(array(select jsonb_array_elements_text(item->'plans')), '{}'),
          nullif(item->>'max_uses', '')::int, nullif(item->>'expires_at', '')::timestamptz,
          coalesce((item->>'active')::boolean, true), coalesce(item->>'note', ''))
  on conflict (code) do update
    set kind = excluded.kind, value = excluded.value, plans = excluded.plans,
        max_uses = excluded.max_uses, expires_at = excluded.expires_at,
        active = excluded.active, note = excluded.note;
  perform public.log_admin('billing_promo', null, jsonb_build_object('code', upper(trim(item->>'code'))));
end $$;

create or replace function public.admin_delete_promo(promo text)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin('billing');
  delete from public.promo_codes where code = promo;
  perform public.log_admin('billing_promo_delete', null, jsonb_build_object('code', promo));
end $$;

-- row: {id, name, price, currency, active}
create or replace function public.admin_save_product(item jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin('billing');
  insert into public.iap_products (id, name, price, currency, active)
  values (lower(trim(item->>'id')), trim(item->>'name'), (item->>'price')::numeric,
          upper(coalesce(item->>'currency', 'INR')), coalesce((item->>'active')::boolean, true))
  on conflict (id) do update
    set name = excluded.name, price = excluded.price, currency = excluded.currency,
        active = excluded.active, updated_at = now();
  perform public.log_admin('billing_product', null, jsonb_build_object('id', lower(trim(item->>'id'))));
end $$;

create or replace function public.admin_delete_product(product text)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin('billing');
  delete from public.iap_products where id = product;
  perform public.log_admin('billing_product_delete', null, jsonb_build_object('id', product));
end $$;

create or replace function public.admin_transactions(days int default 90)
returns table (id uuid, user_id uuid, member_name text, member_email text, kind text, item text,
               amount numeric, currency text, store text, status text, provider_ref text,
               promo_code text, country text, note text, created_at timestamptz, refunded_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.require_admin('billing');
  return query
    select t.id, t.user_id, p.name, coalesce(u.email, u.phone, '')::text, t.kind, t.item, t.amount,
           t.currency, t.store, t.status, t.provider_ref, t.promo_code, t.country, t.note,
           t.created_at, t.refunded_at
      from public.transactions t
      left join public.profiles p on p.id = t.user_id
      left join auth.users u on u.id = t.user_id
     where t.created_at > now() - make_interval(days => greatest(days, 1))
     order by t.created_at desc
     limit 2000;
end $$;

-- A payment taken outside the app (or a test): recorded as store 'manual'.
create or replace function public.admin_record_payment(member uuid, kind text, item text, amount numeric,
                                                       note text default '')
returns uuid language plpgsql security definer set search_path = public as $$
declare
  made uuid;
begin
  perform public.require_admin('billing');
  if not exists (select 1 from public.profiles where id = member and not is_bot) then
    raise exception 'no such member';
  end if;
  made := public.record_payment(member, kind, item, amount, 'INR', 'manual', 'paid', null, null, 'India',
                                coalesce(nullif(trim(note), ''), 'Recorded by an admin'));
  perform public.log_admin('billing_manual_payment', member,
                           jsonb_build_object('item', item, 'amount', amount));
  return made;
end $$;

-- Marks a payment refunded (the refund itself happens at the provider).
-- A refunded subscription ends the plan now.
create or replace function public.admin_refund(tx uuid, reason text default '')
returns void language plpgsql security definer set search_path = public as $$
declare
  t public.transactions;
begin
  perform public.require_admin('billing');
  update public.transactions
     set status = 'refunded', refunded_at = now(),
         note = trim(both ' ' from note || case when coalesce(reason, '') <> '' then ' · Refund: ' || reason else '' end)
   where id = tx and status = 'paid'
   returning * into t;
  if not found then raise exception 'only a paid payment can be refunded'; end if;
  if t.kind = 'subscription' and t.user_id is not null then
    update public.profiles set plan_until = now() where id = t.user_id and plan = t.item;
  end if;
  perform public.log_admin('billing_refund', t.user_id, jsonb_build_object('tx', tx, 'amount', t.amount));
end $$;

-- Revenue over the last [days] days: gross, refunds, net, paying members,
-- active subscriptions and MRR, by day / item / store / country.
create or replace function public.admin_revenue(days int default 30)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  since date := current_date - (greatest(least(days, 365), 1) - 1);
begin
  perform public.require_admin('billing');
  return jsonb_build_object(
    'totals', (select jsonb_build_object(
        'gross', coalesce(sum(amount) filter (where status in ('paid', 'refunded')), 0),
        'refunds', coalesce(sum(amount) filter (where status = 'refunded'), 0),
        'net', coalesce(sum(amount) filter (where status = 'paid'), 0),
        'payments', count(*) filter (where status in ('paid', 'refunded')),
        'failed', count(*) filter (where status = 'failed'),
        'payers', count(distinct user_id) filter (where status = 'paid'))
      from public.transactions where created_at::date >= since),
    'subscriptions', jsonb_build_object(
        'active', (select count(*) from public.profiles p
                    where not p.is_bot and p.plan in ('plus', 'gold', 'platinum') and p.plan_until > now()),
        'mrr', (select coalesce(sum(pp.price), 0) from public.profiles p
                  join public.plan_prices pp on pp.country = 'India' and pp.plan = p.plan
                 where not p.is_bot and p.plan_until > now()),
        'by_plan', (select coalesce(jsonb_object_agg(plan, n), '{}') from (
                      select p.plan, count(*) n from public.profiles p
                       where not p.is_bot and p.plan in ('plus', 'gold', 'platinum') and p.plan_until > now()
                       group by 1) s)),
    'daily', (select coalesce(jsonb_agg(jsonb_build_object(
          'day', d,
          'net', (select coalesce(sum(amount), 0) from public.transactions t
                   where t.status = 'paid' and t.created_at::date = d),
          'refunds', (select coalesce(sum(amount), 0) from public.transactions t
                       where t.status = 'refunded' and t.created_at::date = d)) order by d), '[]')
        from generate_series(since, current_date, interval '1 day') g(d0), lateral (select d0::date as d) s),
    'by_item', (select coalesce(jsonb_agg(jsonb_build_object('item', item, 'kind', kind, 'net', net, 'count', n) order by net desc), '[]')
        from (select item, kind, sum(amount) net, count(*) n from public.transactions
               where status = 'paid' and created_at::date >= since group by 1, 2) s),
    'by_store', (select coalesce(jsonb_object_agg(store, net), '{}')
        from (select store, sum(amount) net from public.transactions
               where status = 'paid' and created_at::date >= since group by 1) s),
    'by_country', (select coalesce(jsonb_object_agg(country, net), '{}')
        from (select country, sum(amount) net from public.transactions
               where status = 'paid' and created_at::date >= since group by 1) s));
end $$;

revoke all on function public.admin_billing_config() from public, anon;
revoke all on function public.admin_save_prices(jsonb) from public, anon;
revoke all on function public.admin_delete_price(text, text) from public, anon;
revoke all on function public.admin_save_promo(jsonb) from public, anon;
revoke all on function public.admin_delete_promo(text) from public, anon;
revoke all on function public.admin_save_product(jsonb) from public, anon;
revoke all on function public.admin_delete_product(text) from public, anon;
revoke all on function public.admin_transactions(int) from public, anon;
revoke all on function public.admin_record_payment(uuid, text, text, numeric, text) from public, anon;
revoke all on function public.admin_refund(uuid, text) from public, anon;
revoke all on function public.admin_revenue(int) from public, anon;
grant execute on function public.admin_billing_config() to authenticated;
grant execute on function public.admin_save_prices(jsonb) to authenticated;
grant execute on function public.admin_delete_price(text, text) to authenticated;
grant execute on function public.admin_save_promo(jsonb) to authenticated;
grant execute on function public.admin_delete_promo(text) to authenticated;
grant execute on function public.admin_save_product(jsonb) to authenticated;
grant execute on function public.admin_delete_product(text) to authenticated;
grant execute on function public.admin_transactions(int) to authenticated;
grant execute on function public.admin_record_payment(uuid, text, text, numeric, text) to authenticated;
grant execute on function public.admin_refund(uuid, text) to authenticated;
grant execute on function public.admin_revenue(int) to authenticated;
