-- Lease ↔ unit status automation + lease auto-expiration/renewal.
--
-- 1) A unit's occupancy follows its leases: as soon as a lease on the unit is
--    'active' the unit becomes 'occupied'; when no active lease remains, an
--    'occupied' unit reverts to 'vacant'. 'under_renovation' is left alone
--    (it's a deliberate manual state) unless an active lease appears, in
--    which case real occupancy wins.
-- 2) Contracts past their end_date stop counting as active. A SECURITY
--    DEFINER sweep handles each one: auto_renew contracts are cloned forward
--    into a fresh contract (renew_lease) while the old one is marked
--    'expired'; the rest simply expire. The status changes fire the cascade
--    in (1), which frees or keeps the unit. Exposed as RPCs the app calls
--    (expire_overdue_leases on load; renew_lease from a "Renouveler" button).
--    (rent generation already ignores leases past end_date, so this is about
--    status accuracy, freeing the local, and rolling contracts over.)

----------------------------------------------------------------------
-- 1) Recompute a single unit's status from its leases
----------------------------------------------------------------------
create or replace function public.sync_unit_status(p_unit_id uuid)
returns void
language plpgsql
security definer
as $$
declare
  v_current unit_status;
  v_new unit_status;
  v_has_active boolean;
begin
  if p_unit_id is null then
    return;
  end if;

  select status into v_current from public.units where id = p_unit_id;
  if v_current is null then
    return; -- unit was deleted
  end if;

  select exists (
    select 1 from public.leases
    where unit_id = p_unit_id and status = 'active'
  ) into v_has_active;

  if v_has_active then
    v_new := 'occupied';
  elsif v_current = 'occupied' then
    v_new := 'vacant';
  else
    v_new := v_current; -- preserve vacant / under_renovation
  end if;

  if v_new is distinct from v_current then
    update public.units
    set status = v_new, updated_at = now()
    where id = p_unit_id;
  end if;
end;
$$;

----------------------------------------------------------------------
-- 2) Trigger: any lease change re-syncs the affected unit(s)
----------------------------------------------------------------------
create or replace function public.leases_sync_unit_status()
returns trigger
language plpgsql
security definer
as $$
begin
  if tg_op = 'INSERT' then
    perform public.sync_unit_status(new.unit_id);
  elsif tg_op = 'UPDATE' then
    perform public.sync_unit_status(new.unit_id);
    if old.unit_id is distinct from new.unit_id then
      perform public.sync_unit_status(old.unit_id);
    end if;
  elsif tg_op = 'DELETE' then
    perform public.sync_unit_status(old.unit_id);
  end if;
  return null; -- AFTER trigger: return value ignored
end;
$$;

drop trigger if exists leases_sync_unit_status on public.leases;
create trigger leases_sync_unit_status
after insert or update or delete on public.leases
for each row
execute function public.leases_sync_unit_status();

----------------------------------------------------------------------
-- 3) Renew a lease = clone it into a fresh contract with the same terms
----------------------------------------------------------------------
-- Auto-renewal is a NEW contract carrying the same infos (unit, tenant,
-- rent, VAT, TOM, deposit, frequency), with dates shifted forward by the
-- original term. The previous contract is marked 'expired'. Generated
-- columns (vat_amount, waste_tax_amount, rent_incl_tax) are recomputed by
-- the schema, so we only copy base columns.
create or replace function public.renew_lease(p_lease_id uuid)
returns uuid
language plpgsql
security definer
as $$
declare
  v_old public.leases%rowtype;
  v_term integer;
  v_new_start date;
  v_new_end date;
  v_new_id uuid;
begin
  select * into v_old from public.leases where id = p_lease_id;
  if v_old.id is null then
    raise exception 'Contrat % introuvable', p_lease_id;
  end if;

  -- Term length in days. Open-ended contracts default to a 1-year renewal.
  if v_old.end_date is null then
    v_term := 365;
    v_new_start := current_date;
  else
    v_term := v_old.end_date - v_old.start_date;
    v_new_start := v_old.end_date + 1;
  end if;
  v_new_end := v_new_start + v_term;

  -- If the contract is so overdue that a single renewal still lands in the
  -- past, start the renewal today — one current contract, never a chain.
  if v_new_end < current_date then
    v_new_start := current_date;
    v_new_end := current_date + v_term;
  end if;

  insert into public.leases (
    unit_id, tenant_id, start_date, end_date, rent_excl_tax, vat_rate,
    deposit, deposit_returned, auto_renew, status, special_conditions,
    waste_tax_rate, payment_frequency
  )
  values (
    v_old.unit_id, v_old.tenant_id, v_new_start, v_new_end, v_old.rent_excl_tax,
    v_old.vat_rate, v_old.deposit, false, v_old.auto_renew, 'active',
    v_old.special_conditions, v_old.waste_tax_rate, v_old.payment_frequency
  )
  returning id into v_new_id;

  update public.leases
  set status = 'expired', updated_at = now()
  where id = p_lease_id;

  return v_new_id;
end;
$$;

grant execute on function public.renew_lease(uuid) to authenticated;

----------------------------------------------------------------------
-- 4) Auto-expire (or auto-renew) leases past their end_date
----------------------------------------------------------------------
-- Contracts flagged auto_renew are cloned forward (see renew_lease); the
-- rest simply expire. Both free/keep the unit via the cascade trigger.
create or replace function public.expire_overdue_leases()
returns integer
language plpgsql
security definer
as $$
declare
  r record;
  v_count integer := 0;
begin
  for r in
    select id, auto_renew
    from public.leases
    where status = 'active'
      and end_date is not null
      and end_date < current_date
  loop
    if r.auto_renew then
      perform public.renew_lease(r.id); -- clones forward + expires the old one
    else
      update public.leases
      set status = 'expired', updated_at = now()
      where id = r.id;
    end if;
    v_count := v_count + 1;
  end loop;
  return v_count; -- contracts processed (expired or renewed)
end;
$$;

-- The app calls this on load; only authenticated users may run it.
grant execute on function public.expire_overdue_leases() to authenticated;

----------------------------------------------------------------------
-- 5) Reconcile existing data on deploy
----------------------------------------------------------------------
-- Expire/renew any already-overdue active leases first…
select public.expire_overdue_leases();
-- …then make every unit's status agree with its current leases.
do $$
declare
  r record;
begin
  for r in select id from public.units loop
    perform public.sync_unit_status(r.id);
  end loop;
end $$;
