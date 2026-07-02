-- Lease ↔ unit status automation + lease auto-expiration.
--
-- 1) A unit's occupancy follows its leases: as soon as a lease on the unit is
--    'active' the unit becomes 'occupied'; when no active lease remains, an
--    'occupied' unit reverts to 'vacant'. 'under_renovation' is left alone
--    (it's a deliberate manual state) unless an active lease appears, in
--    which case real occupancy wins.
-- 2) Contracts past their end_date should stop counting as active. A
--    SECURITY DEFINER function flips 'active' → 'expired' for such leases;
--    the flip fires the cascade in (1), which frees the unit. It is exposed
--    as an RPC the app calls on load so state converges without manual work.
--    (rent generation already ignores leases past end_date, so this is about
--    status accuracy + freeing the local, not rent correctness.)

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
-- 3) Auto-expire leases past their end_date
----------------------------------------------------------------------
create or replace function public.expire_overdue_leases()
returns integer
language plpgsql
security definer
as $$
declare
  v_count integer;
begin
  update public.leases
  set status = 'expired', updated_at = now()
  where status = 'active'
    and end_date is not null
    and end_date < current_date;
  get diagnostics v_count = row_count;
  return v_count; -- number of leases expired (units freed via the cascade)
end;
$$;

-- The app calls this on load; only authenticated users may run it.
grant execute on function public.expire_overdue_leases() to authenticated;

----------------------------------------------------------------------
-- 4) Reconcile existing data on deploy
----------------------------------------------------------------------
-- Flip any already-overdue active leases first…
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
