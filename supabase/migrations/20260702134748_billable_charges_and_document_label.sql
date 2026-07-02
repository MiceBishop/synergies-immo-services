-- Client feedback (2026-07-02):
--   1. Optional display name (label) for documents.
--   2. A billable charge can be added to a tenant's monthly payment: link an
--      expense to a specific rent_due. The tenant then owes rent + those
--      linked billable charges. Non-billable / unlinked billable charges stay
--      out of the tenant's bill (the non-billable ones show up in the owner
--      statement instead).
--
-- To keep payment status correct, the "amount due" for a rent_due becomes
-- amount_incl_tax + sum(linked billable charges). Both the payments trigger
-- and a new expenses trigger route through a shared recompute function.

----------------------------------------------------------------------
-- 1) documents.label — optional human name (distinct from file_name)
----------------------------------------------------------------------
alter table documents add column label text;

----------------------------------------------------------------------
-- 2) expenses.rent_due_id — link a (billable) charge to a tenant's bill
----------------------------------------------------------------------
alter table expenses
  add column rent_due_id uuid references rent_dues(id) on delete set null;
create index idx_expenses_rent_due on expenses(rent_due_id);

----------------------------------------------------------------------
-- 3) Shared status recompute: paid/partial/unpaid from payments vs
--    (rent TTC + linked billable charges)
----------------------------------------------------------------------
create or replace function public.recompute_rent_due_status(p_rent_due_id uuid)
returns void
language plpgsql
security definer
as $$
declare
  v_paid numeric;
  v_due numeric;
  v_charges numeric;
begin
  if p_rent_due_id is null then
    return;
  end if;

  select amount_incl_tax into v_due
  from public.rent_dues
  where id = p_rent_due_id;

  -- Rent due deleted in the same transaction — nothing to update.
  if v_due is null then
    return;
  end if;

  select coalesce(sum(amount), 0) into v_paid
  from public.payments
  where rent_due_id = p_rent_due_id;

  select coalesce(sum(amount), 0) into v_charges
  from public.expenses
  where rent_due_id = p_rent_due_id and billable = true;

  v_due := v_due + v_charges;

  update public.rent_dues
  set status = case
    when v_paid >= v_due then 'paid'::payment_status
    when v_paid > 0 then 'partial'::payment_status
    else 'unpaid'::payment_status
  end
  where id = p_rent_due_id;
end;
$$;

----------------------------------------------------------------------
-- 4) Rewire the payments trigger to the shared function
----------------------------------------------------------------------
create or replace function public.refresh_rent_due_status()
returns trigger
language plpgsql
security definer
as $$
begin
  perform public.recompute_rent_due_status(
    coalesce(new.rent_due_id, old.rent_due_id)
  );
  return null;
end;
$$;
-- trigger payments_update_rent_due_status already exists; the function body
-- is replaced above.

----------------------------------------------------------------------
-- 5) Expenses trigger: (un)linking or editing a billable charge
--    recomputes the affected rent_due status
----------------------------------------------------------------------
create or replace function public.expenses_refresh_rent_due_status()
returns trigger
language plpgsql
security definer
as $$
begin
  if tg_op = 'UPDATE' then
    if old.rent_due_id is distinct from new.rent_due_id then
      perform public.recompute_rent_due_status(old.rent_due_id);
    end if;
    perform public.recompute_rent_due_status(new.rent_due_id);
  elsif tg_op = 'INSERT' then
    perform public.recompute_rent_due_status(new.rent_due_id);
  elsif tg_op = 'DELETE' then
    perform public.recompute_rent_due_status(old.rent_due_id);
  end if;
  return null;
end;
$$;

drop trigger if exists expenses_update_rent_due_status on public.expenses;
create trigger expenses_update_rent_due_status
after insert or update or delete on public.expenses
for each row
execute function public.expenses_refresh_rent_due_status();
