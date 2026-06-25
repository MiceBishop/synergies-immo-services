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
