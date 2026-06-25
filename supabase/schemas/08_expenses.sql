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
