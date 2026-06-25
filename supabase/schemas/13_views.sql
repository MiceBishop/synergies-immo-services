create or replace view v_dashboard_stats as
select
  (select count(*) from units) as total_units,
  (select count(*) from units where status = 'occupied') as occupied_units,
  (select count(*) from units where status = 'vacant') as vacant_units,
  (
    select coalesce(sum(amount_incl_tax), 0)
    from rent_dues
    where due_month = date_trunc('month', current_date)
  ) as expected_rent_this_month,
  (
    select coalesce(sum(p.amount), 0)
    from payments p
    join rent_dues rd on rd.id = p.rent_due_id
    where rd.due_month = date_trunc('month', current_date)
  ) as collected_rent_this_month,
  (
    select coalesce(sum(amount_incl_tax), 0)
    from rent_dues
    where status in ('unpaid', 'overdue')
  ) as total_unpaid;
