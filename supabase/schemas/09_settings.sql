create table settings (
  id uuid primary key default gen_random_uuid(),
  key text unique not null,
  value text not null,
  description text
);
