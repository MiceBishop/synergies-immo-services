-- Client demo feedback (2026-06-29) — contract financial model changes:
--   1. TOM tax (Taxe sur les Ordures Ménagères) — 3.6% at contract level,
--      billed to the tenant like VAT.
--   2. payment_frequency — monthly / quarterly per contract.
--   3. Synergies commission — 10% on collected rent (settings default; used
--      by owner statements). Not a lease column — a global setting for now.
--
-- Notes:
-- - Postgres generated columns cannot reference OTHER generated columns, so
--   rent_incl_tax is expressed purely from base columns (rent_excl_tax,
--   vat_rate, waste_tax_rate).
-- - PG15 can't ALTER a generated column's expression in place, so we drop
--   and re-add rent_incl_tax. rent_dues copies amounts at generation time
--   (no FK to the generated column) and v_dashboard_stats references
--   rent_dues, not leases.rent_incl_tax — so the drop is safe.

----------------------------------------------------------------------
-- 1) payment_frequency enum
----------------------------------------------------------------------
create type payment_frequency as enum ('monthly', 'quarterly');

----------------------------------------------------------------------
-- 2) leases: TOM rate + frequency + regenerated rent_incl_tax
----------------------------------------------------------------------
alter table leases
  add column waste_tax_rate numeric(5,2) default 3.6,
  add column payment_frequency payment_frequency not null default 'monthly';

-- Generated TOM amount (references only base columns).
alter table leases
  add column waste_tax_amount numeric(12,2)
    generated always as (rent_excl_tax * waste_tax_rate / 100) stored;

-- rent_incl_tax now = base + VAT + TOM. Drop + re-add (PG15 can't SET EXPRESSION).
alter table leases drop column rent_incl_tax;
alter table leases
  add column rent_incl_tax numeric(12,2)
    generated always as (
      rent_excl_tax
      + rent_excl_tax * vat_rate / 100
      + rent_excl_tax * waste_tax_rate / 100
    ) stored;

----------------------------------------------------------------------
-- 3) rent_dues: snapshot the TOM amount alongside the existing amounts
----------------------------------------------------------------------
alter table rent_dues
  add column waste_tax_amount numeric(12,2) not null default 0;

----------------------------------------------------------------------
-- 4) settings: commission + TOM defaults (idempotent)
----------------------------------------------------------------------
insert into settings (key, value, description) values
  ('commission_rate', '10', 'Commission Synergies sur les loyers encaissés (%)'),
  ('waste_tax_rate', '3.6', 'Taux TOM — taxe sur les ordures ménagères (%)')
on conflict (key) do nothing;

----------------------------------------------------------------------
-- 5) generate_rent_dues_for_month: respect frequency + include TOM
----------------------------------------------------------------------
-- Monthly leases: one rent due per month.
-- Quarterly leases: one rent due every 3 months (aligned to the lease's
--   start month), amount = 3× the monthly figures.
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
  v_first date := date_trunc('month', target_month)::date;
begin
  return query
  with eligible as (
    select
      l.id,
      l.rent_excl_tax,
      l.vat_amount,
      l.waste_tax_amount,
      l.rent_incl_tax,
      l.payment_frequency,
      -- whole months from the lease's first month to the target month
      (
        (extract(year from v_first)::int * 12 + extract(month from v_first)::int)
        - (
            extract(year from date_trunc('month', l.start_date))::int * 12
            + extract(month from date_trunc('month', l.start_date))::int
          )
      ) as months_diff
    from public.leases l
    where l.status = 'active'
      and l.start_date <= (v_first + interval '1 month' - interval '1 day')::date
      and (l.end_date is null or l.end_date >= v_first)
  ),
  due as (
    select
      e.*,
      case when e.payment_frequency = 'quarterly' then 3 else 1 end as mult
    from eligible e
    where e.payment_frequency = 'monthly'
       or (e.payment_frequency = 'quarterly' and e.months_diff % 3 = 0)
  ),
  inserted as (
    insert into public.rent_dues (
      lease_id, due_month, amount_excl_tax, vat_amount, waste_tax_amount,
      amount_incl_tax, status
    )
    select
      d.id,
      v_first,
      d.rent_excl_tax * d.mult,
      d.vat_amount * d.mult,
      d.waste_tax_amount * d.mult,
      d.rent_incl_tax * d.mult,
      'unpaid'
    from due d
    where not exists (
      select 1 from public.rent_dues rd
      where rd.lease_id = d.id and rd.due_month = v_first
    )
    returning rent_dues.lease_id
  )
  select d.id, exists(select 1 from inserted i where i.lease_id = d.id)
  from due d
  order by d.id;
end;
$$;
