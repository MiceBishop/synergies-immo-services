create table leases (
  id uuid primary key default gen_random_uuid(),
  unit_id uuid references units(id) on delete restrict not null,
  tenant_id uuid references tenants(id) on delete restrict not null,
  start_date date not null,
  end_date date,
  rent_excl_tax numeric(12,2) not null,
  vat_rate numeric(5,2) default 0,
  vat_amount numeric(12,2) generated always as (rent_excl_tax * vat_rate / 100) stored,
  rent_incl_tax numeric(12,2) generated always as (rent_excl_tax + rent_excl_tax * vat_rate / 100) stored,
  deposit numeric(12,2) default 0,
  deposit_returned boolean default false,
  auto_renew boolean default true,
  status lease_status default 'draft',
  special_conditions text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
