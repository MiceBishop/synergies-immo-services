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
