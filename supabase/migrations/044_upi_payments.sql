-- Paying for a plan by UPI, verified by hand.
--
-- An admin sets the UPI ID in the panel (Revenue → UPI payments). In the
-- app a member picks a plan, pays that UPI ID from any UPI app, and enters
-- the UPI reference (UTR) of the payment. The team checks it against the
-- bank statement and verifies it: that records the payment in the ledger
-- (store 'upi') and gives the member the plan for a month. Rejecting tells
-- the member why.

insert into public.app_config (key, value) values
  ('upi', '{"enabled": false, "vpa": "", "payee_name": "Everlane", "note": "Pay the exact amount, then enter the 12-digit UPI reference (UTR) from your payment app."}')
on conflict (key) do nothing;

-- Members read the UPI details with the rest of the app settings.
create or replace function public.app_settings()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_object_agg(key, value), '{}') from public.app_config
   where key in ('maintenance', 'min_version', 'flags', 'onboarding', 'age', 'referral', 'upi')
$$;

-- UPI settings are billing settings.
create or replace function public.admin_set_config(p_key text, p_value jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin(case
    when p_key in ('flags', 'onboarding', 'age', 'referral') then 'content'
    when p_key in ('auto_mod') then 'moderate'
    when p_key in ('phase_out', 'algo') then 'bots'
    when p_key in ('upi') then 'billing'
    else 'team' end);
  if jsonb_typeof(p_value) <> 'object' then raise exception 'value must be an object'; end if;
  insert into public.app_config (key, value, updated_at, updated_by)
  values (p_key, p_value, now(), auth.uid())
  on conflict (key) do update
    set value = public.app_config.value || excluded.value, updated_at = now(), updated_by = auth.uid();
  perform public.log_admin('config', null, jsonb_build_object('key', p_key, 'value', p_value));
end $$;

alter table public.transactions drop constraint if exists transactions_store_check;
alter table public.transactions add constraint transactions_store_check
  check (store in ('razorpay', 'google', 'apple', 'stripe', 'manual', 'upi'));

create table if not exists public.upi_payments (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles (id) on delete set null,
  plan text not null check (plan in ('plus', 'gold', 'platinum')),
  amount numeric(10, 2) not null check (amount > 0),
  utr text not null unique check (utr ~ '^[A-Za-z0-9]{6,35}$'),
  payer_note text not null default '' check (char_length(payer_note) <= 200),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  reason text not null default '',
  transaction_id uuid references public.transactions (id) on delete set null,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid
);
create index if not exists upi_payments_status on public.upi_payments (status, created_at desc);
alter table public.upi_payments enable row level security;
revoke all on public.upi_payments from anon, authenticated;

-- A member says they paid. The amount is the plan's current India price.
create or replace function public.submit_upi_payment(p_plan text, p_utr text, p_note text default '')
returns bigint language plpgsql security definer set search_path = public as $$
declare
  cfg jsonb := (select value from public.app_config where key = 'upi');
  price numeric;
  ref text := upper(regexp_replace(coalesce(p_utr, ''), '\s', '', 'g'));
  made bigint;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if not coalesce((cfg->>'enabled')::boolean, false) or coalesce(cfg->>'vpa', '') = '' then
    raise exception 'UPI payments are not available right now';
  end if;
  select pp.price into price from public.plan_prices pp
   where pp.country = 'India' and pp.plan = p_plan and pp.active;
  if price is null then raise exception 'that plan isn’t available'; end if;
  if ref !~ '^[A-Z0-9]{6,35}$' then
    raise exception 'enter the UPI reference (UTR) from your payment app';
  end if;
  if exists (select 1 from public.upi_payments where utr = ref) then
    raise exception 'this UPI reference was already submitted';
  end if;
  if (select count(*) from public.upi_payments where user_id = auth.uid() and status = 'pending') >= 3 then
    raise exception 'you already have payments waiting to be verified';
  end if;
  insert into public.upi_payments (user_id, plan, amount, utr, payer_note)
  values (auth.uid(), p_plan, price, ref, left(trim(coalesce(p_note, '')), 200))
  returning id into made;
  return made;
end $$;

create or replace function public.my_upi_payments()
returns table (id bigint, plan text, amount numeric, utr text, status text, reason text,
               created_at timestamptz, reviewed_at timestamptz)
language sql stable security definer set search_path = public as $$
  select u.id, u.plan, u.amount, u.utr, u.status, u.reason, u.created_at, u.reviewed_at
    from public.upi_payments u where u.user_id = auth.uid() order by u.created_at desc limit 20
$$;

create or replace function public.admin_upi_payments(p_status text default null)
returns table (id bigint, user_id uuid, member_name text, member_email text, member_phone text,
               member_plan text, member_plan_until timestamptz, plan text, amount numeric, utr text,
               payer_note text, status text, reason text, created_at timestamptz, reviewed_at timestamptz,
               reviewer_email text, transaction_id uuid)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  perform public.require_admin('billing');
  return query
    select u.id, u.user_id, p.name, coalesce(au.email, '')::text, coalesce(au.phone, '')::text,
           p.plan, p.plan_until, u.plan, u.amount, u.utr, u.payer_note, u.status, u.reason,
           u.created_at, u.reviewed_at, coalesce(ru.email, '')::text, u.transaction_id
      from public.upi_payments u
      left join public.profiles p on p.id = u.user_id
      left join auth.users au on au.id = u.user_id
      left join auth.users ru on ru.id = u.reviewed_by
     where p_status is null or u.status = p_status
     order by (u.status = 'pending') desc, u.created_at desc
     limit 500;
end $$;

-- Verify (gives the plan for a month and records the payment) or reject.
create or replace function public.admin_review_upi(p_id bigint, p_approve boolean, p_reason text default '')
returns void language plpgsql security definer set search_path = public as $$
declare
  u public.upi_payments;
  tx uuid;
begin
  perform public.require_admin('billing');
  select * into u from public.upi_payments where id = p_id for update;
  if not found then raise exception 'no such payment'; end if;
  if u.status <> 'pending' then raise exception 'this payment was already reviewed'; end if;
  if p_approve then
    if u.user_id is null then raise exception 'the member’s account no longer exists'; end if;
    tx := public.record_payment(u.user_id, 'subscription', u.plan, u.amount, 'INR', 'upi', 'paid',
                                'UPI-' || u.utr, null, 'India', 'UPI ' || u.utr);
    update public.upi_payments
       set status = 'approved', reviewed_at = now(), reviewed_by = auth.uid(), transaction_id = tx
     where id = p_id;
  else
    update public.upi_payments
       set status = 'rejected', reason = coalesce(nullif(trim(p_reason), ''), 'We couldn’t find this payment.'),
           reviewed_at = now(), reviewed_by = auth.uid()
     where id = p_id;
  end if;
  perform public.log_admin(case when p_approve then 'upi_verified' else 'upi_rejected' end, u.user_id,
                           jsonb_build_object('id', p_id, 'plan', u.plan, 'amount', u.amount, 'utr', u.utr));
end $$;

revoke all on function public.submit_upi_payment(text, text, text) from public, anon;
revoke all on function public.my_upi_payments() from public, anon;
revoke all on function public.admin_upi_payments(text) from public, anon;
revoke all on function public.admin_review_upi(bigint, boolean, text) from public, anon;
grant execute on function public.submit_upi_payment(text, text, text) to authenticated;
grant execute on function public.my_upi_payments() to authenticated;
grant execute on function public.admin_upi_payments(text) to authenticated;
grant execute on function public.admin_review_upi(bigint, boolean, text) to authenticated;
