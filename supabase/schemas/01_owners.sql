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
