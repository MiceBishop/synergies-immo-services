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
