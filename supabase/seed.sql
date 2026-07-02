-- Local-only seed data. Runs on `supabase db reset` against the local stack.
-- NEVER pushed to the remote project. Stable UUIDs so reseeding is idempotent.
--
-- Coverage: 2 owners, 2 buildings (Dakar), 8 units (mixed types/statuses),
-- 3 tenants, 4 leases (residential + commercial, mix of statuses),
-- ~12 rent_dues across the last 3 months, payments for paid/partial dues,
-- 3 expenses (water, syndicate, maintenance).

----------------------------------------------------------------------
-- Owners
----------------------------------------------------------------------
insert into owners (id, last_name, first_name, email, phone, address, tax_id) values
  ('11111111-1111-1111-1111-000000000001', 'Diop', 'Aminata', 'aminata.diop@example.sn', '+221 77 123 45 67', 'Plateau, Dakar', '004567892A1'),
  ('11111111-1111-1111-1111-000000000002', 'Ndiaye', 'Moussa', 'moussa.ndiaye@example.sn', '+221 70 234 56 78', 'Mermoz, Dakar', '004789123B2');

----------------------------------------------------------------------
-- Buildings
----------------------------------------------------------------------
insert into buildings (id, owner_id, name, address, city, floor_count, notes) values
  (
    '22222222-2222-2222-2222-000000000001',
    '11111111-1111-1111-1111-000000000001',
    'Résidence Téranga',
    '12 Avenue Léopold Sédar Senghor',
    'Dakar',
    4,
    'Bâtiment résidentiel avec local commercial au rez-de-chaussée.'
  ),
  (
    '22222222-2222-2222-2222-000000000002',
    '11111111-1111-1111-1111-000000000002',
    'Immeuble Sahel',
    '45 Rue Carnot',
    'Dakar',
    3,
    'Bureaux et commerces, quartier Plateau.'
  );

----------------------------------------------------------------------
-- Units
----------------------------------------------------------------------
insert into units (id, building_id, reference, floor, type, area_sqm, room_count, status, base_rent, monthly_charges, description) values
  -- Résidence Téranga
  ('33333333-3333-3333-3333-000000000001', '22222222-2222-2222-2222-000000000001', 'RDC-COM',  0, 'shop',      45.00, null, 'occupied',          450000, 20000, 'Local commercial sur rue.'),
  ('33333333-3333-3333-3333-000000000002', '22222222-2222-2222-2222-000000000001', 'A-101',    1, 'apartment', 75.50, 3,    'occupied',          350000, 15000, 'F3 avec balcon.'),
  ('33333333-3333-3333-3333-000000000003', '22222222-2222-2222-2222-000000000001', 'A-201',    2, 'apartment', 75.50, 3,    'occupied',          350000, 15000, 'F3 avec balcon.'),
  ('33333333-3333-3333-3333-000000000004', '22222222-2222-2222-2222-000000000001', 'A-301',    3, 'apartment', 90.00, 4,    'vacant',            420000, 18000, 'F4 traversant.'),
  ('33333333-3333-3333-3333-000000000005', '22222222-2222-2222-2222-000000000001', 'SS-P01',  -1, 'parking',   12.50, null, 'occupied',           25000,     0, 'Place de parking couverte.'),
  -- Immeuble Sahel
  ('33333333-3333-3333-3333-000000000006', '22222222-2222-2222-2222-000000000002', 'B-101',    1, 'office',   120.00, 5,    'occupied',          600000, 30000, 'Plateau de bureaux.'),
  ('33333333-3333-3333-3333-000000000007', '22222222-2222-2222-2222-000000000002', 'B-201',    2, 'office',    95.00, 4,    'under_renovation',  500000, 25000, 'En rénovation jusqu''à fin de trimestre.'),
  ('33333333-3333-3333-3333-000000000008', '22222222-2222-2222-2222-000000000002', 'B-301',    3, 'office',   150.00, 6,    'vacant',            750000, 35000, 'Disponible immédiatement.');

----------------------------------------------------------------------
-- Tenants
----------------------------------------------------------------------
insert into tenants (id, last_name, first_name, email, phone, national_id, tax_id, tenant_type, notes) values
  (
    '44444444-4444-4444-4444-000000000001',
    'Sow', 'Fatou',
    'fatou.sow@example.sn',
    '+221 77 345 67 89',
    '1234567890123',
    null,
    'individual',
    'Locataire depuis 2 ans, paiements réguliers.'
  ),
  (
    '44444444-4444-4444-4444-000000000002',
    'Ba', 'Ousmane',
    'ousmane.ba@example.sn',
    '+221 70 456 78 90',
    '9876543210987',
    null,
    'individual',
    null
  ),
  (
    '44444444-4444-4444-4444-000000000003',
    'Société Atlantique SARL', null,
    'contact@atlantique-sn.example',
    '+221 33 567 89 01',
    'SN-DKR-2018-B-12345',
    '004112233C4',
    'company',
    'Cabinet de conseil. Contrat commercial 18% TVA.'
  );

----------------------------------------------------------------------
-- Leases
----------------------------------------------------------------------
-- rent_excl_tax + vat_rate; vat_amount and rent_incl_tax are generated columns.
insert into leases (id, unit_id, tenant_id, start_date, end_date, rent_excl_tax, vat_rate, deposit, auto_renew, status, special_conditions) values
  -- Fatou Sow → A-101 (residential, 0% VAT)
  (
    '55555555-5555-5555-5555-000000000001',
    '33333333-3333-3333-3333-000000000002',
    '44444444-4444-4444-4444-000000000001',
    '2024-09-01', '2025-08-31',
    350000, 0, 700000, true, 'active', null
  ),
  -- Ousmane Ba → A-201 (residential, 0% VAT)
  (
    '55555555-5555-5555-5555-000000000002',
    '33333333-3333-3333-3333-000000000003',
    '44444444-4444-4444-4444-000000000002',
    '2025-01-01', '2025-12-31',
    350000, 0, 700000, true, 'active', null
  ),
  -- Société Atlantique → B-101 (commercial, 18% VAT)
  (
    '55555555-5555-5555-5555-000000000003',
    '33333333-3333-3333-3333-000000000006',
    '44444444-4444-4444-4444-000000000003',
    '2024-06-01', '2026-05-31',
    600000, 18, 1800000, true, 'active', 'Contrat commercial 2 ans, indexation annuelle prévue.'
  ),
  -- Société Atlantique → RDC-COM (commercial, 18% VAT)
  (
    '55555555-5555-5555-5555-000000000004',
    '33333333-3333-3333-3333-000000000001',
    '44444444-4444-4444-4444-000000000003',
    '2024-06-01', '2026-05-31',
    450000, 18, 1350000, true, 'active', null
  );

----------------------------------------------------------------------
-- Rent dues
----------------------------------------------------------------------
-- Generate the last 3 months (current, current-1, current-2) for every active lease.
-- Statuses laid out so dashboards/lists exercise paid + partial + unpaid in parallel.
insert into rent_dues (id, lease_id, due_month, amount_excl_tax, vat_amount, waste_tax_amount, amount_incl_tax, status)
select
  ('66666666-6666-6666-6666-' || lpad(row_number() over (order by l.id, m.offset_months)::text, 12, '0'))::uuid,
  l.id,
  (date_trunc('month', current_date)::date - (m.offset_months || ' months')::interval)::date,
  l.rent_excl_tax,
  l.vat_amount,
  l.waste_tax_amount,
  l.rent_incl_tax,
  case
    when m.offset_months >= 2 then 'paid'::payment_status
    when m.offset_months = 1 then 'partial'::payment_status
    else 'unpaid'::payment_status
  end
from leases l
cross join (values (0), (1), (2)) as m(offset_months)
where l.status = 'active';

----------------------------------------------------------------------
-- Payments
----------------------------------------------------------------------
-- Full payment for paid dues.
insert into payments (rent_due_id, amount, payment_date, method, payment_reference)
select
  rd.id,
  rd.amount_incl_tax,
  (rd.due_month + interval '5 days')::date,
  'bank_transfer',
  'VIR-' || to_char(rd.due_month, 'YYYYMM') || '-' || substring(rd.lease_id::text, 1, 8)
from rent_dues rd
where rd.status = 'paid';

-- Partial (50%) payment for partial dues.
insert into payments (rent_due_id, amount, payment_date, method, payment_reference, notes)
select
  rd.id,
  round(rd.amount_incl_tax / 2, 0),
  (rd.due_month + interval '10 days')::date,
  'cash',
  null,
  'Acompte versé, solde à régulariser.'
from rent_dues rd
where rd.status = 'partial';

----------------------------------------------------------------------
-- Expenses
----------------------------------------------------------------------
insert into expenses (building_id, unit_id, type, label, amount, expense_date, billable, notes) values
  (
    '22222222-2222-2222-2222-000000000001', null,
    'water', 'Facture SDE mai',
    85000, (current_date - interval '20 days')::date,
    true, 'À répercuter dans les charges trimestrielles.'
  ),
  (
    '22222222-2222-2222-2222-000000000001', null,
    'syndicate', 'Charges syndic T2',
    120000, (current_date - interval '15 days')::date,
    false, null
  ),
  (
    null, '33333333-3333-3333-3333-000000000007',
    'maintenance', 'Travaux de rénovation B-201',
    1450000, (current_date - interval '8 days')::date,
    false, 'Peinture + plomberie. Devis approuvé.'
  );
