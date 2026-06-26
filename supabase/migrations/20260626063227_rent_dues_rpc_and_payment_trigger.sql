-- Phase 3 — Financial engine plumbing:
--   1. generate_rent_dues_for_month(target_month) RPC
--      Idempotent: for the given month it creates one rent_due per eligible
--      active lease, skipping any that already exist for that (lease_id,
--      due_month) pair. Returns one row per eligible lease tagged
--      `generated = true` (new) or `false` (already existed) so the UI can
--      report "N new, M existing".
--
--   2. payments_update_rent_due_status trigger
--      Keeps rent_dues.status in sync atomically every time a payment is
--      inserted, updated or deleted. The trigger sets the status to
--      paid / partial / unpaid based on the sum of payments vs amount_incl_tax.
--      The fourth value `overdue` is time-derived and applied at the read
--      layer (UI) when status='unpaid' AND due_month < current month.

----------------------------------------------------------------------
-- 1) RPC: generate rent dues for a given month
----------------------------------------------------------------------
create or replace function public.generate_rent_dues_for_month(
  target_month date
)
returns table (
  lease_id uuid,
  generated boolean
)
language plpgsql
security invoker
as $$
declare
  v_first_of_month date := date_trunc('month', target_month)::date;
begin
  return query
  with eligible as (
    select l.id,
           l.rent_excl_tax,
           l.vat_amount,
           l.rent_incl_tax
    from public.leases l
    where l.status = 'active'
      and l.start_date <= (v_first_of_month + interval '1 month' - interval '1 day')::date
      and (l.end_date is null or l.end_date >= v_first_of_month)
  ),
  inserted as (
    insert into public.rent_dues (
      lease_id, due_month, amount_excl_tax, vat_amount, amount_incl_tax, status
    )
    select e.id, v_first_of_month, e.rent_excl_tax, e.vat_amount, e.rent_incl_tax, 'unpaid'
    from eligible e
    where not exists (
      select 1 from public.rent_dues rd
      where rd.lease_id = e.id and rd.due_month = v_first_of_month
    )
    returning rent_dues.lease_id
  )
  select e.id,
         exists(select 1 from inserted i where i.lease_id = e.id) as generated
  from eligible e
  order by e.id;
end;
$$;

grant execute on function public.generate_rent_dues_for_month(date) to authenticated;

----------------------------------------------------------------------
-- 2) Trigger: keep rent_dues.status in sync with payments
----------------------------------------------------------------------
create or replace function public.refresh_rent_due_status()
returns trigger
language plpgsql
security definer
as $$
declare
  v_rent_due_id uuid := coalesce(new.rent_due_id, old.rent_due_id);
  v_total numeric;
  v_due numeric;
begin
  if v_rent_due_id is null then
    return null;
  end if;

  select coalesce(sum(amount), 0) into v_total
  from public.payments
  where rent_due_id = v_rent_due_id;

  select amount_incl_tax into v_due
  from public.rent_dues
  where id = v_rent_due_id;

  if v_due is null then
    -- Rent due was deleted in the same transaction; nothing to update.
    return null;
  end if;

  update public.rent_dues
  set status = case
    when v_total >= v_due then 'paid'::payment_status
    when v_total > 0 then 'partial'::payment_status
    else 'unpaid'::payment_status
  end
  where id = v_rent_due_id;

  return null;
end;
$$;

drop trigger if exists payments_update_rent_due_status on public.payments;
create trigger payments_update_rent_due_status
after insert or update or delete on public.payments
for each row
execute function public.refresh_rent_due_status();
