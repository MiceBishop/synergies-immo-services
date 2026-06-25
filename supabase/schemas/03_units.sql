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
