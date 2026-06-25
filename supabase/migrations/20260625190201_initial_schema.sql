-- =============================================
-- 00_enums.sql
-- =============================================
create type unit_type as enum ('apartment', 'office', 'shop', 'parking', 'storage');
create type unit_status as enum ('vacant', 'occupied', 'under_renovation');
create type lease_status as enum ('active', 'expired', 'terminated', 'draft');
create type payment_method as enum ('cash', 'bank_transfer', 'check', 'direct_debit');
create type payment_status as enum ('paid', 'partial', 'unpaid', 'overdue');
create type expense_type as enum ('water', 'electricity', 'syndicate', 'maintenance', 'tax', 'other');
create type document_type as enum ('national_id', 'business_registration', 'tax_id', 'signed_lease', 'receipt', 'invoice', 'other');
create type notification_channel as enum ('email', 'sms', 'whatsapp');
create type notification_status as enum ('pending', 'sent', 'failed');

-- =============================================
-- 01_owners.sql
-- =============================================
create table owners (
  id uuid primary key default gen_random_uuid(),
  last_name text not null,
  first_name text,
  email text,
  phone text,
  address text,
  tax_id text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- =============================================
-- 02_buildings.sql
-- =============================================
create table buildings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references owners(id) on delete set null,
  name text not null,
  address text not null,
  city text not null,
  floor_count integer default 1,
  photo_url text,
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- =============================================
-- 03_units.sql
-- =============================================
create table units (
  id uuid primary key default gen_random_uuid(),
  building_id uuid references buildings(id) on delete cascade not null,
  reference text not null,
  floor integer,
  type unit_type not null,
  area_sqm numeric(8,2),
  room_count integer,
  status unit_status default 'vacant',
  base_rent numeric(12,2),
  monthly_charges numeric(12,2) default 0,
  description text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- =============================================
-- 04_tenants.sql
-- =============================================
create table tenants (
  id uuid primary key default gen_random_uuid(),
  last_name text not null,
  first_name text,
  email text,
  phone text not null,
  national_id text,
  tax_id text,
  previous_address text,
  tenant_type text default 'individual',
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- =============================================
-- 05_leases.sql
-- =============================================
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

-- =============================================
-- 06_rent_dues.sql
-- =============================================
create table rent_dues (
  id uuid primary key default gen_random_uuid(),
  lease_id uuid references leases(id) on delete cascade not null,
  due_month date not null,
  amount_excl_tax numeric(12,2) not null,
  vat_amount numeric(12,2) not null,
  amount_incl_tax numeric(12,2) not null,
  status payment_status default 'unpaid',
  created_at timestamptz default now()
);

-- =============================================
-- 07_payments.sql
-- =============================================
create table payments (
  id uuid primary key default gen_random_uuid(),
  rent_due_id uuid references rent_dues(id) on delete restrict not null,
  amount numeric(12,2) not null,
  payment_date date not null,
  method payment_method not null,
  payment_reference text,
  notes text,
  created_at timestamptz default now()
);

-- =============================================
-- 08_expenses.sql
-- =============================================
create table expenses (
  id uuid primary key default gen_random_uuid(),
  building_id uuid references buildings(id) on delete cascade,
  unit_id uuid references units(id) on delete cascade,
  type expense_type not null,
  label text not null,
  amount numeric(12,2) not null,
  expense_date date not null,
  billable boolean default false,
  notes text,
  created_at timestamptz default now(),
  constraint chk_expense_target check (building_id is not null or unit_id is not null)
);

-- =============================================
-- 09_settings.sql
-- =============================================
create table settings (
  id uuid primary key default gen_random_uuid(),
  key text unique not null,
  value text not null,
  description text
);

-- =============================================
-- 10_notifications.sql
-- =============================================
create table notifications (
  id uuid primary key default gen_random_uuid(),
  channel notification_channel not null,
  recipient text not null,
  subject text,
  body text not null,
  status notification_status default 'pending',
  reference_type text,
  reference_id uuid,
  error_message text,
  created_at timestamptz default now()
);

-- =============================================
-- 11_documents.sql
-- =============================================
create table documents (
  id uuid primary key default gen_random_uuid(),
  type document_type not null,
  file_name text not null,
  storage_path text not null,
  file_size_bytes integer,
  tenant_id uuid references tenants(id) on delete cascade,
  lease_id uuid references leases(id) on delete cascade,
  building_id uuid references buildings(id) on delete cascade,
  unit_id uuid references units(id) on delete cascade,
  created_at timestamptz default now()
);

-- =============================================
-- 12_indexes.sql
-- =============================================
create index idx_units_building on units(building_id);
create index idx_leases_unit on leases(unit_id);
create index idx_leases_tenant on leases(tenant_id);
create index idx_leases_status on leases(status);
create index idx_rent_dues_lease on rent_dues(lease_id);
create index idx_rent_dues_month on rent_dues(due_month);
create index idx_rent_dues_status on rent_dues(status);
create index idx_payments_rent_due on payments(rent_due_id);
create index idx_expenses_building on expenses(building_id);

-- =============================================
-- 13_views.sql
-- =============================================
create or replace view v_dashboard_stats as
select
  (select count(*) from units) as total_units,
  (select count(*) from units where status = 'occupied') as occupied_units,
  (select count(*) from units where status = 'vacant') as vacant_units,
  (
    select coalesce(sum(amount_incl_tax), 0)
    from rent_dues
    where due_month = date_trunc('month', current_date)
  ) as expected_rent_this_month,
  (
    select coalesce(sum(p.amount), 0)
    from payments p
    join rent_dues rd on rd.id = p.rent_due_id
    where rd.due_month = date_trunc('month', current_date)
  ) as collected_rent_this_month,
  (
    select coalesce(sum(amount_incl_tax), 0)
    from rent_dues
    where status in ('unpaid', 'overdue')
  ) as total_unpaid;

