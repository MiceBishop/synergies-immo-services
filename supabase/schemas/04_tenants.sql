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
