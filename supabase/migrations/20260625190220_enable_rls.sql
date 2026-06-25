-- Enable Row Level Security on all application tables.
-- MVP policy: any authenticated user has full access (single admin role).
-- Future v2: add a `role` column to auth.users metadata and split per-role policies.

alter table owners enable row level security;
alter table buildings enable row level security;
alter table units enable row level security;
alter table tenants enable row level security;
alter table leases enable row level security;
alter table rent_dues enable row level security;
alter table payments enable row level security;
alter table expenses enable row level security;
alter table documents enable row level security;
alter table settings enable row level security;
alter table notifications enable row level security;

create policy "admin_all" on owners for all to authenticated using (true) with check (true);
create policy "admin_all" on buildings for all to authenticated using (true) with check (true);
create policy "admin_all" on units for all to authenticated using (true) with check (true);
create policy "admin_all" on tenants for all to authenticated using (true) with check (true);
create policy "admin_all" on leases for all to authenticated using (true) with check (true);
create policy "admin_all" on rent_dues for all to authenticated using (true) with check (true);
create policy "admin_all" on payments for all to authenticated using (true) with check (true);
create policy "admin_all" on expenses for all to authenticated using (true) with check (true);
create policy "admin_all" on documents for all to authenticated using (true) with check (true);
create policy "admin_all" on settings for all to authenticated using (true) with check (true);
create policy "admin_all" on notifications for all to authenticated using (true) with check (true);
