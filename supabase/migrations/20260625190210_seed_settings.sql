-- Seed default config for Senegal/XOF deployment.
-- All values are strings — coerce on the client side.
insert into settings (key, value, description) values
  ('currency_code', 'XOF', 'ISO 4217 currency code'),
  ('currency_symbol', 'FCFA', 'Symbol displayed after amounts'),
  ('currency_locale', 'fr-SN', 'Intl.NumberFormat locale'),
  ('country_code', 'SN', 'ISO country code'),
  ('vat_rate_residential', '0', 'VAT rate for residential (%)'),
  ('vat_rate_commercial_standard', '18', 'Standard commercial VAT rate Senegal (%)'),
  ('vat_rate_commercial_reduced', '10', 'Reduced commercial VAT rate (%)'),
  ('fiscal_year_start', '01-01', 'Fiscal year start (MM-DD)'),
  ('company_name', 'Synergies Immo', 'Company legal name'),
  ('company_address', '', 'Company address'),
  ('company_phone', '', 'Main phone number'),
  ('company_email', '', 'Main email'),
  ('company_tax_id', '', 'NINEA (Senegal) or ICE (Morocco)');
