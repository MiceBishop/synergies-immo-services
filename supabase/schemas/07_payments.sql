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
