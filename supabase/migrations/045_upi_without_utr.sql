-- UPI payments no longer ask the member for the UPI reference (UTR): they
-- tap "I've paid", and the team matches the payment in their UPI app by
-- the note ("Everlane Gold - Pratik (9C0375)") and the amount. A UTR can
-- still be sent (older app versions) and is kept when given.

alter table public.upi_payments alter column utr drop not null;
alter table public.upi_payments drop constraint if exists upi_payments_utr_check;
alter table public.upi_payments add constraint upi_payments_utr_check
  check (utr is null or utr ~ '^[A-Za-z0-9]{6,35}$');

create or replace function public.submit_upi_payment(p_plan text, p_utr text default '', p_note text default '')
returns bigint language plpgsql security definer set search_path = public as $$
declare
  cfg jsonb := (select value from public.app_config where key = 'upi');
  price numeric;
  ref text := nullif(upper(regexp_replace(coalesce(p_utr, ''), '\s', '', 'g')), '');
  made bigint;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if not coalesce((cfg->>'enabled')::boolean, false) or coalesce(cfg->>'vpa', '') = '' then
    raise exception 'UPI payments are not available right now';
  end if;
  select pp.price into price from public.plan_prices pp
   where pp.country = 'India' and pp.plan = p_plan and pp.active;
  if price is null then raise exception 'that plan isn’t available'; end if;
  if ref is not null and ref !~ '^[A-Z0-9]{6,35}$' then
    raise exception 'that UPI reference doesn’t look right';
  end if;
  if ref is not null and exists (select 1 from public.upi_payments where utr = ref) then
    raise exception 'this UPI reference was already submitted';
  end if;
  if exists (select 1 from public.upi_payments where user_id = auth.uid() and status = 'pending'
              and plan = p_plan and created_at > now() - interval '10 minutes') then
    raise exception 'we already have this payment — we’ll verify it soon';
  end if;
  if (select count(*) from public.upi_payments where user_id = auth.uid() and status = 'pending') >= 3 then
    raise exception 'you already have payments waiting to be verified';
  end if;
  insert into public.upi_payments (user_id, plan, amount, utr, payer_note)
  values (auth.uid(), p_plan, price, ref, left(trim(coalesce(p_note, '')), 200))
  returning id into made;
  return made;
end $$;

-- Verifying works without a UTR: the ledger reference is the request id.
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
                                'UPI-' || coalesce(u.utr, 'REQ' || u.id), null, 'India',
                                'UPI' || coalesce(' ' || u.utr, ' request #' || u.id));
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

update public.app_config
   set value = value || '{"note": "Pay the exact amount from any UPI app, then tap “I’ve paid”. We check every payment and turn on your plan."}'
 where key = 'upi' and value->>'note' like '%UTR%';
